import MapKit
import Photos
import SwiftUI

struct AssetDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    let asset: PHAsset

    private let rows: [AssetDetailRow]
    private let resourceRows: [AssetDetailRow]

    init(asset: PHAsset) {
        self.asset = asset
        rows = AssetDetailsView.assetRows(for: asset)
        resourceRows = AssetDetailsView.resourceRows(for: asset)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    preview
                        .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                Section("Photo Details") {
                    ForEach(rows) { row in
                        detailRow(row)
                    }
                }

                if !resourceRows.isEmpty {
                    Section("File") {
                        ForEach(resourceRows) { row in
                            detailRow(row)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var preview: some View {
        HStack(spacing: 14) {
            AssetImageView(asset: asset, contentMode: .fill, quality: .thumbnail)
                .frame(width: 74, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(primaryTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text(primarySubtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }

    private var primaryTitle: String {
        asset.creationDate?.formatted(.dateTime.weekday(.wide).month(.wide).day().year()) ?? "No Date"
    }

    private var primarySubtitle: String {
        asset.creationDate?.formatted(.dateTime.hour().minute()) ?? Self.mediaTypeText(for: asset)
    }

    private func detailRow(_ row: AssetDetailRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Label(row.title, systemImage: row.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 116, alignment: .leading)

            Spacer(minLength: 8)

            Text(row.value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }

    private static func assetRows(for asset: PHAsset) -> [AssetDetailRow] {
        var rows: [AssetDetailRow] = [
            AssetDetailRow(title: "Type", value: mediaTypeText(for: asset), icon: asset.mediaType == .video ? "video.fill" : "photo.fill"),
            AssetDetailRow(title: "Size", value: "\(asset.pixelWidth) x \(asset.pixelHeight)", icon: "aspectratio"),
            AssetDetailRow(title: "Megapixels", value: megapixelsText(for: asset), icon: "camera.metering.matrix")
        ]

        if asset.mediaType == .video {
            rows.append(AssetDetailRow(title: "Duration", value: durationText(for: asset), icon: "timer"))
        }

        rows.append(contentsOf: [
            AssetDetailRow(title: "Created", value: formattedDate(asset.creationDate), icon: "calendar"),
            AssetDetailRow(title: "Modified", value: formattedDate(asset.modificationDate), icon: "clock.arrow.circlepath"),
            AssetDetailRow(title: "Favorite", value: asset.isFavorite ? "Yes" : "No", icon: "heart.fill"),
            AssetDetailRow(title: "Hidden", value: asset.isHidden ? "Yes" : "No", icon: "eye.slash.fill"),
            AssetDetailRow(title: "Source", value: sourceText(for: asset.sourceType), icon: "folder"),
            AssetDetailRow(title: "Subtypes", value: subtypeText(for: asset), icon: "tag")
        ])

        if let burstIdentifier = asset.burstIdentifier {
            rows.append(AssetDetailRow(title: "Burst", value: burstIdentifier, icon: "square.stack.3d.up"))
        }

        if let location = asset.location {
            rows.append(AssetDetailRow(title: "Location", value: locationText(for: location), icon: "location.fill"))
        }

        rows.append(AssetDetailRow(title: "Asset ID", value: asset.localIdentifier, icon: "number"))

        return rows
    }

    private static func resourceRows(for asset: PHAsset) -> [AssetDetailRow] {
        PHAssetResource.assetResources(for: asset).flatMap { resource in
            [
                AssetDetailRow(title: "Name", value: resource.originalFilename, icon: "doc"),
                AssetDetailRow(title: "Kind", value: resourceTypeText(for: resource.type), icon: "square.stack")
            ]
        }
    }

    private static func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Not available" }
        return date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
    }

    private static func mediaTypeText(for asset: PHAsset) -> String {
        switch asset.mediaType {
        case .image:
            return asset.mediaSubtypes.contains(.photoScreenshot) ? "Screenshot" : "Photo"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .unknown:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }

    private static func megapixelsText(for asset: PHAsset) -> String {
        let megapixels = Double(asset.pixelWidth * asset.pixelHeight) / 1_000_000
        guard megapixels > 0 else { return "Not available" }
        return String(format: "%.1f MP", megapixels)
    }

    private static func durationText(for asset: PHAsset) -> String {
        let total = Int(asset.duration.rounded())
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }

    private static func sourceText(for sourceType: PHAssetSourceType) -> String {
        var sources: [String] = []

        if sourceType.contains(.typeUserLibrary) {
            sources.append("User Library")
        }

        if sourceType.contains(.typeCloudShared) {
            sources.append("Shared")
        }

        if sourceType.contains(.typeiTunesSynced) {
            sources.append("Synced")
        }

        return sources.isEmpty ? "Unknown" : sources.joined(separator: ", ")
    }

    private static func subtypeText(for asset: PHAsset) -> String {
        var subtypes: [String] = []

        if asset.mediaSubtypes.contains(.photoScreenshot) {
            subtypes.append("Screenshot")
        }

        if asset.mediaSubtypes.contains(.photoLive) {
            subtypes.append("Live Photo")
        }

        if asset.mediaSubtypes.contains(.photoPanorama) {
            subtypes.append("Panorama")
        }

        if asset.mediaSubtypes.contains(.photoHDR) {
            subtypes.append("HDR")
        }

        if asset.mediaSubtypes.contains(.photoDepthEffect) {
            subtypes.append("Depth Effect")
        }

        if asset.mediaSubtypes.contains(.videoHighFrameRate) {
            subtypes.append("High Frame Rate")
        }

        if asset.mediaSubtypes.contains(.videoTimelapse) {
            subtypes.append("Timelapse")
        }

        if #available(iOS 15, *), asset.mediaSubtypes.contains(.videoCinematic) {
            subtypes.append("Cinematic")
        }

        return subtypes.isEmpty ? "None" : subtypes.joined(separator: ", ")
    }

    private static func resourceTypeText(for type: PHAssetResourceType) -> String {
        switch type {
        case .photo:
            return "Photo"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .alternatePhoto:
            return "Alternate Photo"
        case .fullSizePhoto:
            return "Full Size Photo"
        case .fullSizeVideo:
            return "Full Size Video"
        case .adjustmentData:
            return "Adjustment Data"
        case .adjustmentBasePhoto:
            return "Adjustment Base Photo"
        case .adjustmentBaseVideo:
            return "Adjustment Base Video"
        case .pairedVideo:
            return "Paired Video"
        case .fullSizePairedVideo:
            return "Full Size Paired Video"
        case .adjustmentBasePairedVideo:
            return "Adjustment Base Paired Video"
        case .photoProxy:
            return "Photo Proxy"
        @unknown default:
            return "Unknown"
        }
    }

    private static func locationText(for location: CLLocation) -> String {
        let latitude = String(format: "%.5f", location.coordinate.latitude)
        let longitude = String(format: "%.5f", location.coordinate.longitude)
        return "\(latitude), \(longitude)"
    }
}

private struct AssetDetailRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
}

#Preview {
    AssetDetailsView(asset: PHAsset())
        .preferredColorScheme(.dark)
}
