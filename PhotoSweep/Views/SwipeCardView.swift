import Photos
import SwiftUI
import UIKit

struct SwipeCardView: View {
    let asset: PHAsset
    let onKeep: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGSize = .zero
    @State private var isExiting = false

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

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                if isScreenshot {
                    screenshotBackdrop
                }

                AssetImageView(asset: asset, contentMode: .fit)
                    .padding(isScreenshot ? 18 : 0)
            }
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
                .scaleEffect(isExiting ? 0.94 : 1)
                .shadow(color: .black.opacity(0.34), radius: 14, x: 0, y: 9)
        }
        .contentShape(Rectangle())
        .offset(offset)
        .rotationEffect(rotation)
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard !isExiting else { return }
                    offset = CGSize(
                        width: value.translation.width,
                        height: value.translation.height * 0.28
                    )
                }
                .onEnded { value in
                    guard !isExiting else { return }
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
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current photo")
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
