import Photos
import SwiftUI
import UIKit

struct SwipeCardView: View {
    let asset: PHAsset
    let onKeep: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGSize = .zero
    @State private var isExiting = false
    @State private var showingDetails = false
    @State private var zoomScale: CGFloat = 1
    @State private var lastZoomScale: CGFloat = 1
    @State private var imageOffset: CGSize = .zero
    @State private var lastImageOffset: CGSize = .zero

    private let minimumZoomScale: CGFloat = 1
    private let maximumZoomScale: CGFloat = 4

    private var rotation: Angle {
        .degrees(Double(offset.width / 32))
    }

    private var dragProgress: CGFloat {
        min(abs(offset.width) / 145, 1)
    }

    private var activeTint: Color {
        offset.width < 0 ? Color(red: 0.88, green: 0.20, blue: 0.24) : Color(red: 0.08, green: 0.56, blue: 0.36)
    }

    private var isScreenshot: Bool {
        asset.mediaSubtypes.contains(.photoScreenshot)
    }

    private var isZoomed: Bool {
        zoomScale > 1.01
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                imageLayer
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(activeTint.opacity(dragProgress * 0.62), lineWidth: 4)
                }
                .overlay(alignment: .topLeading) {
                    decisionBadge(
                        title: "Delete",
                        icon: "minus.circle.fill",
                        color: Color(red: 0.88, green: 0.20, blue: 0.24),
                        opacity: min(max(-offset.width / 115, 0), 1)
                    )
                }
                .overlay(alignment: .topTrailing) {
                    decisionBadge(
                        title: "Keep",
                        icon: "checkmark.circle.fill",
                        color: Color(red: 0.08, green: 0.56, blue: 0.36),
                        opacity: min(max(offset.width / 115, 0), 1)
                    )
                }
                .overlay(alignment: .bottomLeading) {
                    assetMeta
                }
                .overlay(alignment: .top) {
                    topMetaBar
                }
                .scaleEffect(isExiting ? 0.94 : 1)
                .shadow(color: .black.opacity(0.34), radius: 14, x: 0, y: 9)
            }
            .contentShape(Rectangle())
            .offset(offset)
            .rotationEffect(isZoomed ? .zero : rotation)
            .gesture(dragGesture(in: proxy.size))
            .simultaneousGesture(zoomGesture(in: proxy.size))
            .onTapGesture(count: 2) {
                toggleZoom(in: proxy.size)
            }
        }
        .sheet(isPresented: $showingDetails) {
            AssetDetailsView(asset: asset)
                .preferredColorScheme(.dark)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current photo")
    }

    private var imageLayer: some View {
        ZStack {
            if isScreenshot {
                screenshotBackdrop
            }

            AssetImageView(asset: asset, contentMode: .fit)
                .padding(isScreenshot ? 18 : 0)
                .scaleEffect(zoomScale)
                .offset(imageOffset)
        }
    }

    private var topMetaBar: some View {
        HStack(spacing: 10) {
            Label(dateTimeText, systemImage: "calendar")
                .font(.caption.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(.black.opacity(0.58), in: Capsule())

            Spacer(minLength: 8)

            Button {
                showingDetails = true
            } label: {
                Image(systemName: "eye.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.58), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View photo details")
        }
        .padding(14)
        .opacity(isExiting ? 0 : 1)
    }

    @ViewBuilder
    private var assetMeta: some View {
        if asset.mediaType == .video {
            metaChip {
                Label(durationText, systemImage: "video.fill")
            }
        } else if asset.mediaSubtypes.contains(.photoScreenshot) {
            metaChip {
                Label("Screenshot", systemImage: "iphone")
            }
        } else {
            EmptyView()
        }
    }

    private var screenshotBackdrop: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.04, green: 0.045, blue: 0.055))

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                .padding(12)
        }
    }

    private var dateText: String {
        guard let date = asset.creationDate else { return "Photo" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private var dateTimeText: String {
        guard let date = asset.creationDate else { return "No Date" }
        return date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute())
    }

    private var durationText: String {
        let total = Int(asset.duration.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func metaChip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.footnote.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(.white)
            .background(.black.opacity(0.58), in: Capsule())
            .padding(14)
    }

    private func decisionBadge(title: String, icon: String, color: Color, opacity: Double) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(color.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            }
            .padding(18)
            .opacity(opacity)
            .scaleEffect(0.92 + (opacity * 0.08))
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isExiting else { return }

                if isZoomed {
                    let proposedOffset = CGSize(
                        width: lastImageOffset.width + value.translation.width,
                        height: lastImageOffset.height + value.translation.height
                    )
                    imageOffset = clampedImageOffset(proposedOffset, in: size)
                } else {
                    offset = CGSize(
                        width: value.translation.width,
                        height: value.translation.height * 0.28
                    )
                }
            }
            .onEnded { value in
                guard !isExiting else { return }

                if isZoomed {
                    lastImageOffset = clampedImageOffset(imageOffset, in: size)
                    imageOffset = lastImageOffset
                    return
                }

                let threshold: CGFloat = 118
                let predictedWidth = value.predictedEndTranslation.width
                if value.translation.width <= -threshold || predictedWidth <= -220 {
                    animateOut(direction: -1, completion: onDelete)
                } else if value.translation.width >= threshold || predictedWidth >= 220 {
                    animateOut(direction: 1, completion: onKeep)
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        offset = .zero
                    }
                }
            }
    }

    private func zoomGesture(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard !isExiting else { return }
                zoomScale = clampedZoomScale(lastZoomScale * value)
                imageOffset = clampedImageOffset(imageOffset, in: size)
            }
            .onEnded { value in
                guard !isExiting else { return }
                zoomScale = clampedZoomScale(lastZoomScale * value)
                lastZoomScale = zoomScale

                if !isZoomed {
                    resetZoom(animated: true)
                } else {
                    lastImageOffset = clampedImageOffset(imageOffset, in: size)
                    imageOffset = lastImageOffset
                }
            }
    }

    private func toggleZoom(in size: CGSize) {
        guard !isExiting else { return }

        if isZoomed {
            resetZoom(animated: true)
        } else {
            withAnimation(.snappy(duration: 0.22)) {
                zoomScale = 2.25
                lastZoomScale = zoomScale
                imageOffset = clampedImageOffset(.zero, in: size)
                lastImageOffset = imageOffset
            }
        }
    }

    private func resetZoom(animated: Bool) {
        let updates = {
            zoomScale = minimumZoomScale
            lastZoomScale = minimumZoomScale
            imageOffset = .zero
            lastImageOffset = .zero
        }

        if animated {
            withAnimation(.snappy(duration: 0.22)) {
                updates()
            }
        } else {
            updates()
        }
    }

    private func clampedZoomScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumZoomScale), maximumZoomScale)
    }

    private func clampedImageOffset(_ offset: CGSize, in size: CGSize) -> CGSize {
        guard zoomScale > minimumZoomScale else { return .zero }

        let maximumX = max((size.width * (zoomScale - 1)) / 2, 0)
        let maximumY = max((size.height * (zoomScale - 1)) / 2, 0)

        return CGSize(
            width: min(max(offset.width, -maximumX), maximumX),
            height: min(max(offset.height, -maximumY), maximumY)
        )
    }

    private func animateOut(direction: CGFloat, completion: @escaping () -> Void) {
        guard !isExiting else { return }
        UIImpactFeedbackGenerator(style: direction < 0 ? .medium : .light).impactOccurred()
        isExiting = true

        withAnimation(.snappy(duration: 0.22, extraBounce: 0.05)) {
            offset = CGSize(width: direction * 760, height: 34)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            offset = .zero
            isExiting = false
            completion()
        }
    }
}
