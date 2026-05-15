import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var selectedPage = 0

    private let pages = OnboardingPage.allPages
    private let keepColor = Color(red: 0.18, green: 0.78, blue: 0.49)

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 18)

            TabView(selection: $selectedPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                        .padding(.horizontal, 22)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 18) {
                pageDots

                Button {
                    advance()
                } label: {
                    HStack(spacing: 10) {
                        Text(selectedPage == pages.count - 1 ? "Start Cleaning" : "Continue")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(keepColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(selectedPage == pages.count - 1 ? "Start cleaning" : "Continue onboarding")

                Button {
                    onComplete()
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .frame(height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .background(background)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .background(keepColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("PhotoSweep")
                .font(.system(.headline, design: .rounded).weight(.black))
                .foregroundStyle(.white)

            Spacer()
        }
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == selectedPage ? keepColor : Color.white.opacity(0.18))
                    .frame(width: index == selectedPage ? 22 : 7, height: 7)
                    .animation(.snappy(duration: 0.22), value: selectedPage)
            }
        }
        .accessibilityHidden(true)
    }

    private var background: some View {
        ZStack {
            Color.black

            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.12, blue: 0.11).opacity(0.92),
                    Color.black,
                    Color(red: 0.04, green: 0.05, blue: 0.08).opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private func advance() {
        if selectedPage == pages.count - 1 {
            onComplete()
        } else {
            withAnimation(.snappy(duration: 0.28)) {
                selectedPage += 1
            }
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            visual
                .frame(maxWidth: .infinity)
                .frame(height: 300)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.76)

                Text(page.subtitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)

            Spacer(minLength: 12)
        }
    }

    @ViewBuilder
    private var visual: some View {
        switch page.visual {
        case .swipes:
            SwipePreviewVisual()
        case .duplicates:
            DuplicatePreviewVisual()
        case .privacy:
            PrivacyPreviewVisual()
        }
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let visual: OnboardingVisual

    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            title: "Clean your camera roll fast",
            subtitle: "Swipe left to mark clutter. Swipe right to keep what matters.",
            visual: .swipes
        ),
        OnboardingPage(
            title: "Catch duplicates and heavy clutter",
            subtitle: "Review duplicate copies, screenshots, and videos from one focused cleanup flow.",
            visual: .duplicates
        ),
        OnboardingPage(
            title: "Private by design",
            subtitle: "Your library stays on your iPhone. Nothing is uploaded, and iOS asks before anything is deleted.",
            visual: .privacy
        )
    ]
}

private enum OnboardingVisual {
    case swipes
    case duplicates
    case privacy
}

private struct SwipePreviewVisual: View {
    private let keepColor = Color(red: 0.18, green: 0.78, blue: 0.49)
    private let deleteColor = Color(red: 1.0, green: 0.32, blue: 0.36)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.14))
                .frame(width: 214, height: 256)
                .rotationEffect(.degrees(-5))
                .shadow(color: .black.opacity(0.26), radius: 18, y: 12)
                .overlay {
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.44, blue: 0.67),
                                Color(red: 0.19, green: 0.72, blue: 0.47)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 172)

                        HStack {
                            Label("Delete", systemImage: "arrow.left")
                                .foregroundStyle(deleteColor)

                            Spacer()

                            Label("Keep", systemImage: "arrow.right")
                                .foregroundStyle(keepColor)
                        }
                        .font(.caption.weight(.black))
                        .padding(14)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                }

            swipePill(title: "Delete", systemImage: "minus.circle.fill", color: deleteColor)
                .offset(x: -92, y: 86)

            swipePill(title: "Keep", systemImage: "checkmark.circle.fill", color: keepColor)
                .offset(x: 90, y: -94)
        }
    }

    private func swipePill(title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.black))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.black.opacity(0.62), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.32), lineWidth: 1)
            }
    }
}

private struct DuplicatePreviewVisual: View {
    private let keepColor = Color(red: 0.18, green: 0.78, blue: 0.49)
    private let deleteColor = Color(red: 1.0, green: 0.32, blue: 0.36)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    duplicateTile(color: keepColor, icon: "checkmark", label: "Keep")
                    duplicateTile(color: deleteColor, icon: "trash", label: "Copy")
                }

                HStack(spacing: 8) {
                    filterToken("Screens")
                    filterToken("Videos")
                    filterToken("Large")
                }
            }
        }
    }

    private func duplicateTile(color: Color, icon: String, label: String) -> some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.90), Color.white.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 112, height: 136)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 32, height: 32)
                        .background(color, in: Circle())
                        .padding(10)
                }

            Text(label)
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
        }
    }

    private func filterToken(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}

private struct PrivacyPreviewVisual: View {
    private let keepColor = Color(red: 0.18, green: 0.78, blue: 0.49)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(keepColor.opacity(0.16))
                        .frame(width: 124, height: 124)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 58, weight: .black))
                        .foregroundStyle(keepColor)
                }

                VStack(spacing: 10) {
                    privacyRow("On-device", icon: "iphone")
                    privacyRow("No uploads", icon: "icloud.slash")
                    privacyRow("Review first", icon: "checkmark.shield")
                }
            }
        }
    }

    private func privacyRow(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white.opacity(0.82))
            .frame(width: 178, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    OnboardingView {}
        .preferredColorScheme(.dark)
}
