import Combine
import Photos
import SwiftUI
import UIKit

enum AssetImageQuality: String {
    case full
    case thumbnail
}

enum PhotoImagePipeline {
    static let manager = PHCachingImageManager()

    static func targetSize(for displaySize: CGSize, quality: AssetImageQuality) -> CGSize {
        let scale = UIScreen.main.scale
        let minimumPixelSize: CGFloat = quality == .thumbnail ? 180 : 700
        return CGSize(
            width: max(displaySize.width * scale, minimumPixelSize),
            height: max(displaySize.height * scale, minimumPixelSize)
        )
    }

    static func options(for quality: AssetImageQuality) -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = quality == .thumbnail ? .fastFormat : .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = quality == .full
        return options
    }

    static func contentMode(for contentMode: ContentMode) -> PHImageContentMode {
        contentMode == .fill ? .aspectFill : .aspectFit
    }

    static func preheat(
        assets: [PHAsset],
        displaySize: CGSize,
        contentMode: ContentMode,
        quality: AssetImageQuality
    ) {
        guard !assets.isEmpty else { return }
        manager.startCachingImages(
            for: assets,
            targetSize: targetSize(for: displaySize, quality: quality),
            contentMode: Self.contentMode(for: contentMode),
            options: options(for: quality)
        )
    }
}

@MainActor
final class AssetImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var requestID: PHImageRequestID?
    private var requestedAssetID: String?

    func load(asset: PHAsset, targetSize: CGSize, contentMode: ContentMode, quality: AssetImageQuality) {
        if requestedAssetID != asset.localIdentifier {
            image = nil
        }
        requestedAssetID = asset.localIdentifier
        if let requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }

        requestID = PhotoImagePipeline.manager.requestImage(
            for: asset,
            targetSize: PhotoImagePipeline.targetSize(for: targetSize, quality: quality),
            contentMode: PhotoImagePipeline.contentMode(for: contentMode),
            options: PhotoImagePipeline.options(for: quality)
        ) { [weak self] image, _ in
            let assetID = asset.localIdentifier
            Task { @MainActor in
                guard self?.requestedAssetID == assetID else { return }
                self?.image = image
            }
        }
    }

    deinit {
        if let requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
    }
}

struct AssetImageView: View {
    let asset: PHAsset
    let contentMode: ContentMode
    let quality: AssetImageQuality

    @StateObject private var loader = AssetImageLoader()

    init(asset: PHAsset, contentMode: ContentMode, quality: AssetImageQuality = .full) {
        self.asset = asset
        self.contentMode = contentMode
        self.quality = quality
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(Color(red: 0.05, green: 0.05, blue: 0.06))

                if let image = loader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
            }
            .task(id: "\(asset.localIdentifier)-\(quality.rawValue)") {
                loader.load(asset: asset, targetSize: proxy.size, contentMode: contentMode, quality: quality)
            }
        }
    }
}
