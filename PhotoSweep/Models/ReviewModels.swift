import Foundation
import Photos

enum CleanupFilter: String, CaseIterable, Identifiable {
    case photos
    case screenshots
    case videos
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photos: "Photos"
        case .screenshots: "Screens"
        case .videos: "Videos"
        case .favorites: "Favorites"
        }
    }

    var icon: String {
        switch self {
        case .photos: "photo"
        case .screenshots: "iphone"
        case .videos: "video"
        case .favorites: "heart"
        }
    }

    func includes(_ asset: PHAsset) -> Bool {
        switch self {
        case .photos:
            return asset.mediaType == .image && !asset.mediaSubtypes.contains(.photoScreenshot)
        case .screenshots:
            return asset.mediaType == .image && asset.mediaSubtypes.contains(.photoScreenshot)
        case .videos:
            return asset.mediaType == .video
        case .favorites:
            return asset.isFavorite
        }
    }
}

enum ReviewDecision: String, Codable {
    case keep
    case delete
}

struct ReviewAction: Identifiable {
    let id = UUID()
    let assetID: String
    let decision: ReviewDecision
    let batchID: UUID?
    let date = Date()

    init(assetID: String, decision: ReviewDecision, batchID: UUID? = nil) {
        self.assetID = assetID
        self.decision = decision
        self.batchID = batchID
    }
}

struct DuplicateGroup: Identifiable {
    let id = UUID()
    let assets: [PHAsset]

    var keeper: PHAsset {
        assets[0]
    }

    var duplicates: [PHAsset] {
        Array(assets.dropFirst())
    }

    var duplicateCount: Int {
        max(assets.count - 1, 0)
    }
}

enum LibraryAccessState: Equatable {
    case unknown
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted

    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .limited:
            self = .limited
        @unknown default:
            self = .unknown
        }
    }

    var canReadAndWrite: Bool {
        self == .authorized || self == .limited
    }
}
