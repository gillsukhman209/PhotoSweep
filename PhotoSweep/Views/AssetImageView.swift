import Combine
import Photos
import SwiftUI

enum AssetImageQuality: String {
    case full
    case thumbnail
}

@MainActor
final class AssetImageLoader: ObservableObject {
    @Published var image: UIImage?
    private let manager = PHImageManager.default()
    private var requestID: PHImageRequestID?
    private var requestedAssetID: String?

    func load(asset: PHAsset, targetSize: CGSize, contentMode: ContentMode, quality: AssetImageQuality) {
        if requestedAssetID != asset.localIdentifier {
            image = nil
        }
        requestedAssetID = asset.localIdentifier
        if let requestID {
            manager.cancelImageRequest(requestID)
        }

        let scale = UIScreen.main.scale
        let minimumPixelSize: CGFloat = quality == .thumbnail ? 180 : 600
        let requestSize = CGSize(
            width: max(targetSize.width * scale, minimumPixelSize),
            height: max(targetSize.height * scale, minimumPixelSize)
        )

        let options = PHImageRequestOptions()
        options.deliveryMode = quality == .thumbnail ? .fastFormat : .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        requestID = manager.requestImage(
            for: asset,
            targetSize: requestSize,
            contentMode: contentMode == .fill ? .aspectFill : .aspectFit,
            options: options
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
            manager.cancelImageRequest(requestID)
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
