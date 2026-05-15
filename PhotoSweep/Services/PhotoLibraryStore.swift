import Foundation
import Combine
import Photos
import SwiftUI
import UIKit

@MainActor
final class PhotoLibraryStore: ObservableObject {
    private let keptAssetIDsKey = "PhotoSweep.keptAssetIDs"
    private let queuedDeleteAssetIDsKey = "PhotoSweep.queuedDeleteAssetIDs"
    private let duplicateHashCacheKey = "PhotoSweep.duplicateHashCache.v1"

    @Published private(set) var accessState: LibraryAccessState = .unknown
    @Published private(set) var assets: [PHAsset] = []
    @Published private(set) var decisions: [String: ReviewDecision] = [:]
    @Published private(set) var history: [ReviewAction] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isDeleting = false
    @Published private(set) var isScanningDuplicates = false
    @Published private(set) var duplicateScanProgress = 0.0
    @Published private(set) var duplicateGroups: [DuplicateGroup] = []
    @Published var filter: CleanupFilter = .photos
    @Published var message: String?

    private var keptAssetIDs: Set<String>
    private var queuedDeleteAssetIDs: Set<String>
    private var duplicateHashCache: [String: UInt64]
    private var duplicateScanTask: Task<Void, Never>?

    init() {
        keptAssetIDs = Set(UserDefaults.standard.stringArray(forKey: keptAssetIDsKey) ?? [])
        queuedDeleteAssetIDs = Set(UserDefaults.standard.stringArray(forKey: queuedDeleteAssetIDsKey) ?? [])
        duplicateHashCache = Self.loadDuplicateHashCache(from: duplicateHashCacheKey)
    }

    var currentAsset: PHAsset? {
        var index = currentIndex
        while index < assets.count {
            let asset = assets[index]
            if decisions[asset.localIdentifier] == nil {
                return asset
            }
            index += 1
        }
        return nil
    }

    var remainingCount: Int {
        max(assets.count - currentIndex, 0)
    }

    var reviewedCount: Int {
        decisions.count
    }

    var keptCount: Int {
        decisions.values.filter { $0 == .keep }.count
    }

    var queuedDeleteAssets: [PHAsset] {
        let queuedVisibleAssets = assets.filter { queuedDeleteAssetIDs.contains($0.localIdentifier) }
        let visibleAssetIDs = Set(queuedVisibleAssets.map(\.localIdentifier))
        let missingAssetIDs = queuedDeleteAssetIDs.subtracting(visibleAssetIDs)
        guard !missingAssetIDs.isEmpty else { return queuedVisibleAssets }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(missingAssetIDs), options: nil)
        var missingAssets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            missingAssets.append(asset)
        }

        return (queuedVisibleAssets + missingAssets).sorted { lhs, rhs in
            let lhsDate = lhs.creationDate ?? .distantPast
            let rhsDate = rhs.creationDate ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    var deleteCount: Int {
        queuedDeleteAssetIDs.count
    }

    var progress: Double {
        guard !assets.isEmpty else { return 0 }
        return Double(min(currentIndex, assets.count)) / Double(assets.count)
    }

    var dateJumpRange: ClosedRange<Date>? {
        let dates = assets.compactMap(\.creationDate)
        guard let oldest = dates.min(), let newest = dates.max() else { return nil }
        return oldest...newest
    }

    var reviewMonths: [PhotoMonth] {
        let calendar = Calendar.current
        var countsByMonth: [Date: Int] = [:]

        for asset in assets where decisions[asset.localIdentifier] == nil {
            guard let creationDate = asset.creationDate else { continue }
            let components = calendar.dateComponents([.year, .month], from: creationDate)
            guard let monthStart = calendar.date(from: components) else { continue }
            countsByMonth[monthStart, default: 0] += 1
        }

        return countsByMonth
            .map { PhotoMonth(startDate: $0.key, count: $0.value) }
            .sorted { $0.startDate > $1.startDate }
    }

    func upcomingAssets(limit: Int = 15) -> [PHAsset] {
        guard limit > 0, let currentAsset else { return [] }
        guard let startIndex = assets.firstIndex(where: { $0.localIdentifier == currentAsset.localIdentifier }) else {
            return []
        }

        var upcoming: [PHAsset] = []
        upcoming.reserveCapacity(limit)

        for asset in assets.dropFirst(startIndex + 1) where decisions[asset.localIdentifier] == nil {
            upcoming.append(asset)
            if upcoming.count == limit {
                break
            }
        }

        return upcoming
    }

    func refreshAuthorization() {
        accessState = LibraryAccessState(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                self.accessState = LibraryAccessState(status)
                if self.accessState.canReadAndWrite {
                    await self.loadAssets(resetSession: true)
                }
            }
        }
    }

    func loadAssets(resetSession: Bool) async {
        refreshAuthorization()
        guard accessState.canReadAndWrite else { return }

        isLoading = true
        message = nil
        defer { isLoading = false }

        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]

        let fetchResult = PHAsset.fetchAssets(with: options)
        var nextAssets: [PHAsset] = []
        var seenAssetIDs = Set<String>()
        nextAssets.reserveCapacity(fetchResult.count)

        fetchResult.enumerateObjects { asset, _, _ in
            if self.filter.includes(asset),
               !self.keptAssetIDs.contains(asset.localIdentifier),
               seenAssetIDs.insert(asset.localIdentifier).inserted {
                nextAssets.append(asset)
            }
        }

        assets = nextAssets

        if resetSession {
            currentIndex = 0
            restoreQueuedDeleteDecisions(keepingCurrentKeeps: false)
            history = []
        } else {
            restoreQueuedDeleteDecisions(keepingCurrentKeeps: true)
            currentIndex = min(currentIndex, assets.count)
            normalizeCurrentIndex()
        }
    }

    func changeFilter(to newFilter: CleanupFilter) {
        guard filter != newFilter else { return }
        filter = newFilter
        Task {
            await loadAssets(resetSession: true)
        }
    }

    func keepCurrent() {
        decide(.keep)
    }

    func queueDeleteCurrent() {
        guard let asset = currentAsset else { return }
        guard asset.canPerform(.delete) else {
            message = "This item cannot be deleted by third-party apps."
            return
        }
        decide(.delete)
    }

    func keepUntil(_ target: PHAsset) {
        guard let currentAsset else { return }
        guard let startIndex = assets.firstIndex(where: { $0.localIdentifier == currentAsset.localIdentifier }),
              let targetIndex = assets.firstIndex(where: { $0.localIdentifier == target.localIdentifier }),
              targetIndex > startIndex else {
            return
        }

        let batchID = UUID()
        for asset in assets[startIndex..<targetIndex] where decisions[asset.localIdentifier] == nil {
            decisions[asset.localIdentifier] = .keep
            history.append(ReviewAction(assetID: asset.localIdentifier, decision: .keep, batchID: batchID))
            rememberKeptAssetID(asset.localIdentifier)
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            currentIndex = targetIndex
            normalizeCurrentIndex()
        }
    }

    func jumpToDate(_ date: Date) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart) ?? date

        if jump(toFirstAssetBetween: dayStart...dayEnd) {
            return
        }

        if jump(toFirstAsset: dayEnd) {
            message = "No unreviewed items on that date. Jumped to the next older item."
        } else {
            message = "No unreviewed items found on or before that date."
        }
    }

    func jumpToMonth(_ month: PhotoMonth) {
        let calendar = Calendar.current
        guard let monthEnd = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: month.startDate) else {
            jumpToDate(month.startDate)
            return
        }

        if !jump(toFirstAssetBetween: month.startDate...monthEnd) {
            message = "No unreviewed items left in \(month.title)."
        }
    }

    private func decide(_ decision: ReviewDecision) {
        guard let asset = currentAsset else { return }
        guard decisions[asset.localIdentifier] == nil else { return }
        decisions[asset.localIdentifier] = decision
        history.append(ReviewAction(assetID: asset.localIdentifier, decision: decision))
        if decision == .keep {
            rememberKeptAssetID(asset.localIdentifier)
        } else {
            rememberQueuedDeleteAssetID(asset.localIdentifier)
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            if let assetIndex = assets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
                currentIndex = min(assetIndex + 1, assets.count)
            } else {
                currentIndex = min(currentIndex + 1, assets.count)
            }
            normalizeCurrentIndex()
        }
    }

    private func jump(toFirstAssetBetween range: ClosedRange<Date>) -> Bool {
        guard let targetIndex = assets.firstIndex(where: { asset in
            guard decisions[asset.localIdentifier] == nil,
                  let creationDate = asset.creationDate else {
                return false
            }

            return range.contains(creationDate)
        }) else {
            return false
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            currentIndex = targetIndex
            normalizeCurrentIndex()
        }
        return true
    }

    private func jump(toFirstAsset onOrBeforeDate: Date) -> Bool {
        guard let targetIndex = assets.firstIndex(where: { asset in
            guard decisions[asset.localIdentifier] == nil,
                  let creationDate = asset.creationDate else {
                return false
            }

            return creationDate <= onOrBeforeDate
        }) else {
            return false
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            currentIndex = targetIndex
            normalizeCurrentIndex()
        }
        return true
    }

    func undo() {
        guard let last = history.popLast() else { return }
        var undoneActions = [last]

        if let batchID = last.batchID {
            while let previous = history.last, previous.batchID == batchID {
                undoneActions.append(history.removeLast())
            }
        }

        for action in undoneActions {
            decisions[action.assetID] = nil
            if action.decision == .keep {
                forgetKeptAssetID(action.assetID)
            } else {
                forgetQueuedDeleteAssetID(action.assetID)
            }
        }

        let targetIndex = undoneActions
            .compactMap { action in
                assets.firstIndex { $0.localIdentifier == action.assetID }
            }
            .min()

        if let targetIndex {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                currentIndex = targetIndex
            }
        }
    }

    func removeFromDeleteQueue(_ asset: PHAsset) {
        decisions[asset.localIdentifier] = .keep
        history.append(ReviewAction(assetID: asset.localIdentifier, decision: .keep))
        forgetQueuedDeleteAssetID(asset.localIdentifier)
        rememberKeptAssetID(asset.localIdentifier)
    }

    func startDuplicateScan() {
        guard duplicateScanTask == nil, !isScanningDuplicates else { return }
        duplicateScanTask = Task { [weak self] in
            await self?.scanForDuplicates()
            await MainActor.run {
                self?.duplicateScanTask = nil
            }
        }
    }

    func cancelDuplicateScan() {
        duplicateScanTask?.cancel()
        duplicateScanTask = nil
        isScanningDuplicates = false
    }

    private func scanForDuplicates() async {
        refreshAuthorization()
        guard accessState.canReadAndWrite else { return }

        isScanningDuplicates = true
        duplicateScanProgress = 0
        duplicateGroups = []
        defer { isScanningDuplicates = false }

        let scanAssets = fetchAllVisibleMediaAssets()
        let buckets = Dictionary(grouping: scanAssets) { asset in
            duplicateBucketKey(for: asset)
        }
        let candidateBuckets = buckets.values.filter { $0.count > 1 }
        let totalCandidates = max(candidateBuckets.reduce(0) { $0 + $1.count }, 1)
        var processed = 0

        var unsavedHashCount = 0
        var allGroups: [DuplicateGroup] = []
        var lastPublish = Date.distantPast

        for bucket in candidateBuckets.sorted(by: { $0.count > $1.count }) {
            var hashes: [(asset: PHAsset, hash: UInt64)] = []
            hashes.reserveCapacity(bucket.count)

            for startIndex in stride(from: 0, to: bucket.count, by: 12) {
                if Task.isCancelled { return }

                let batch = Array(bucket[startIndex..<min(startIndex + 12, bucket.count)])
                var uncachedAssets: [PHAsset] = []
                uncachedAssets.reserveCapacity(batch.count)

                for asset in batch {
                    let cacheKey = duplicateHashCacheKey(for: asset)
                    if let cachedHash = duplicateHashCache[cacheKey] {
                        hashes.append((asset, cachedHash))
                    } else {
                        uncachedAssets.append(asset)
                    }
                }

                let batchHashes = await withTaskGroup(
                    of: (String, PHAsset, UInt64)?.self,
                    returning: [(cacheKey: String, asset: PHAsset, hash: UInt64)].self
                ) { group in
                    for asset in uncachedAssets {
                        let cacheKey = duplicateHashCacheKey(for: asset)
                        group.addTask {
                            if Task.isCancelled { return nil }
                            guard let hash = await Self.perceptualHash(for: asset) else { return nil }
                            return (cacheKey, asset, hash)
                        }
                    }

                    var results: [(cacheKey: String, asset: PHAsset, hash: UInt64)] = []
                    for await result in group {
                        if let result {
                            results.append(result)
                        }
                    }
                    return results
                }

                for result in batchHashes {
                    duplicateHashCache[result.cacheKey] = result.hash
                    hashes.append((result.asset, result.hash))
                    unsavedHashCount += 1
                }

                if unsavedHashCount >= 250 {
                    saveDuplicateHashCache()
                    unsavedHashCount = 0
                }

                processed += batch.count
                duplicateScanProgress = Double(processed) / Double(totalCandidates)
                await Task.yield()
            }

            let newGroups = duplicateGroups(from: hashes)
            if !newGroups.isEmpty {
                allGroups = (allGroups + newGroups)
                    .filter { $0.assets.count > 1 }
                    .sorted { lhs, rhs in
                        lhs.duplicateCount > rhs.duplicateCount
                    }

                if Date().timeIntervalSince(lastPublish) > 0.35 {
                    duplicateGroups = allGroups
                    lastPublish = Date()
                }
            }
            await Task.yield()
        }

        if unsavedHashCount > 0 {
            saveDuplicateHashCache()
        }
        duplicateGroups = allGroups
        duplicateScanProgress = 1
    }

    func markDuplicateExtrasForDeletion(in group: DuplicateGroup) {
        if decisions[group.keeper.localIdentifier] == nil {
            decisions[group.keeper.localIdentifier] = .keep
            history.append(ReviewAction(assetID: group.keeper.localIdentifier, decision: .keep))
            rememberKeptAssetID(group.keeper.localIdentifier)
        }

        for asset in group.duplicates where asset.canPerform(.delete) {
            decisions[asset.localIdentifier] = .delete
            history.append(ReviewAction(assetID: asset.localIdentifier, decision: .delete))
            rememberQueuedDeleteAssetID(asset.localIdentifier)
        }

        normalizeCurrentIndex()
    }

    func markAllDuplicateExtrasForDeletion() {
        for group in duplicateGroups {
            markDuplicateExtrasForDeletion(in: group)
        }
    }

    func restartSession() {
        restoreQueuedDeleteDecisions(keepingCurrentKeeps: false)
        history = []
        currentIndex = 0
        normalizeCurrentIndex()
        message = nil
    }

    func deleteQueuedAssets() async {
        let targets = queuedDeleteAssets
        guard !targets.isEmpty else { return }

        isDeleting = true
        message = nil
        defer { isDeleting = false }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.deleteAssets(targets as NSArray)
                } completionHandler: { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: PhotoSweepError.deleteFailed)
                    }
                }
            }

            message = "Deleted \(targets.count) item\(targets.count == 1 ? "" : "s"). Empty Recently Deleted in Photos to reclaim storage immediately."
            targets.forEach { forgetQueuedDeleteAssetID($0.localIdentifier) }
            decisions = decisions.filter { _, decision in decision != .delete }
            await loadAssets(resetSession: false)
        } catch {
            message = error.localizedDescription
        }
    }

    private func normalizeCurrentIndex() {
        while currentIndex < assets.count, decisions[assets[currentIndex].localIdentifier] != nil {
            currentIndex += 1
        }
    }

    private func restoreQueuedDeleteDecisions(keepingCurrentKeeps: Bool) {
        decisions = keepingCurrentKeeps ? decisions.filter { _, decision in decision == .keep } : [:]
        for asset in assets where queuedDeleteAssetIDs.contains(asset.localIdentifier) {
            decisions[asset.localIdentifier] = .delete
        }
    }

    private func rememberKeptAssetID(_ assetID: String) {
        guard keptAssetIDs.insert(assetID).inserted else { return }
        saveKeptAssetIDs()
    }

    private func forgetKeptAssetID(_ assetID: String) {
        guard keptAssetIDs.remove(assetID) != nil else { return }
        saveKeptAssetIDs()
    }

    private func saveKeptAssetIDs() {
        UserDefaults.standard.set(Array(keptAssetIDs), forKey: keptAssetIDsKey)
    }

    private func rememberQueuedDeleteAssetID(_ assetID: String) {
        guard queuedDeleteAssetIDs.insert(assetID).inserted else { return }
        saveQueuedDeleteAssetIDs()
    }

    private func forgetQueuedDeleteAssetID(_ assetID: String) {
        guard queuedDeleteAssetIDs.remove(assetID) != nil else { return }
        saveQueuedDeleteAssetIDs()
    }

    private func saveQueuedDeleteAssetIDs() {
        UserDefaults.standard.set(Array(queuedDeleteAssetIDs), forKey: queuedDeleteAssetIDsKey)
    }

    private func fetchAllVisibleMediaAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]

        let fetchResult = PHAsset.fetchAssets(with: options)
        var fetchedAssets: [PHAsset] = []
        var seenAssetIDs = Set<String>()
        fetchedAssets.reserveCapacity(fetchResult.count)

        fetchResult.enumerateObjects { asset, _, _ in
            guard asset.mediaType == .image || asset.mediaType == .video else { return }
            guard !self.keptAssetIDs.contains(asset.localIdentifier) else { return }
            guard seenAssetIDs.insert(asset.localIdentifier).inserted else { return }
            fetchedAssets.append(asset)
        }

        return fetchedAssets
    }

    private func duplicateBucketKey(for asset: PHAsset) -> String {
        let shortSide = min(asset.pixelWidth, asset.pixelHeight)
        let longSide = max(asset.pixelWidth, asset.pixelHeight)
        let dateBucket = Int((asset.creationDate?.timeIntervalSince1970 ?? 0) / 86_400)

        if asset.mediaType == .video {
            let durationBucket = Int(asset.duration.rounded())
            return "video-\(shortSide)x\(longSide)-\(durationBucket)-\(dateBucket)"
        }

        return "image-\(shortSide)x\(longSide)-\(dateBucket)"
    }

    private func duplicateGroups(
        from hashes: [(asset: PHAsset, hash: UInt64)]
    ) -> [DuplicateGroup] {
        var clusters: [[(asset: PHAsset, hash: UInt64)]] = []
        let threshold = 4

        for candidate in hashes {
            var matchedIndex: Int?

            for index in clusters.indices {
                guard let representative = clusters[index].first else { continue }
                let distance = Self.hammingDistance(candidate.hash, representative.hash)

                if distance <= threshold {
                    matchedIndex = index
                    break
                }
            }

            if let matchedIndex {
                clusters[matchedIndex].append(candidate)
            } else {
                clusters.append([candidate])
            }
        }

        return clusters
            .filter { $0.count > 1 }
            .map { cluster in
                DuplicateGroup(assets: sortedDuplicateAssets(cluster.map(\.asset)))
            }
    }

    private func sortedDuplicateAssets(_ assets: [PHAsset]) -> [PHAsset] {
        assets.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite
            }

            let lhsDate = lhs.creationDate ?? .distantFuture
            let rhsDate = rhs.creationDate ?? .distantFuture
            return lhsDate < rhsDate
        }
    }

    private func duplicateHashCacheKey(for asset: PHAsset) -> String {
        let duration = Int(asset.duration.rounded())
        return "\(asset.localIdentifier)|\(asset.mediaType.rawValue)|\(asset.pixelWidth)x\(asset.pixelHeight)|\(duration)"
    }

    private func saveDuplicateHashCache() {
        let encoded = duplicateHashCache.mapValues { String($0) }
        UserDefaults.standard.set(encoded, forKey: duplicateHashCacheKey)
    }

    private static func loadDuplicateHashCache(from key: String) -> [String: UInt64] {
        guard let encoded = UserDefaults.standard.dictionary(forKey: key) as? [String: String] else {
            return [:]
        }

        return encoded.reduce(into: [:]) { result, item in
            if let value = UInt64(item.value) {
                result[item.key] = value
            }
        }
    }

    private nonisolated static func perceptualHash(for asset: PHAsset) async -> UInt64? {
        guard let image = await thumbnail(for: asset) else { return nil }
        return await Task.detached(priority: .utility) {
            differenceHash(from: image)
        }.value
    }

    private nonisolated static func thumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false

            var didResume = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 72, height: 72),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !didResume else { return }
                if let image {
                    didResume = true
                    continuation.resume(returning: image)
                    return
                }

                let isCancelled = (info?[PHImageCancelledKey] as? Bool) == true
                let hasError = info?[PHImageErrorKey] != nil
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                if isCancelled || hasError || !isDegraded {
                    didResume = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private nonisolated static func differenceHash(from image: UIImage) -> UInt64? {
        guard let cgImage = image.cgImage else { return nil }

        let width = 9
        let height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        var bit = 0
        for y in 0..<height {
            for x in 0..<(width - 1) {
                let left = pixels[(y * width) + x]
                let right = pixels[(y * width) + x + 1]
                if left > right {
                    hash |= UInt64(1) << UInt64(bit)
                }
                bit += 1
            }
        }

        return hash
    }

    private nonisolated static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }
}

enum PhotoSweepError: LocalizedError {
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .deleteFailed:
            return "Photos did not complete the delete request."
        }
    }
}
