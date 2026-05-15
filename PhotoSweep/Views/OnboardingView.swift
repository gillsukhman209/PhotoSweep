import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var selectedPage = 0

    private let pages = OnboardingPage.allPages
    private let accent = Color(red: 0.30, green: 0.36, blue: 1.0)
    private let accentEnd = Color(red: 0.38, green: 0.20, blue: 1.0)
    private let background = Color(red: 0.06, green: 0.07, blue: 0.13)

    var body: some View {
        VStack(spacing: 0) {
            progressBars
                .padding(.horizontal, 22)
                .padding(.top, 16)

            TabView(selection: $selectedPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            bottomControls
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
        }
        .background(background.ignoresSafeArea())
    }

    private var progressBars: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { index in
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(accent)
                                .frame(width: proxy.size.width * fillAmount(for: index))
                        }
                }
                .frame(height: 5)
            }
        }
        .animation(.snappy(duration: 0.28), value: selectedPage)
        .accessibilityHidden(true)
    }

    private var bottomControls: some View {
        VStack(spacing: 15) {
            Button {
                advance()
            } label: {
                Text(selectedPage == pages.count - 1 ? "Start Cleaning" : "Continue")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.26, green: 0.48, blue: 1.0), accentEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }
            .buttonStyle(.plain)

            Button {
                onComplete()
            } label: {
                Text("Skip")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(height: 28)
            }
            .buttonStyle(.plain)
        }
    }

    private func fillAmount(for index: Int) -> CGFloat {
        if index < selectedPage { return 1 }
        if index == selectedPage { return 0.78 }
        return 0
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
        VStack(spacing: 18) {
            Spacer(minLength: 18)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)

                Text(page.subtitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .minimumScaleFactor(0.80)
            }
            .padding(.horizontal, 22)

            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: page.imageHeight)
                .padding(.horizontal, page.horizontalPadding)
                .accessibilityHidden(true)

            Spacer(minLength: 10)
        }
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let imageHeight: CGFloat
    let horizontalPadding: CGFloat

    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            title: "Swipe Through Your Library",
            subtitle: "Delete clutter on the left. Keep memories on the right.",
            imageName: "OnboardingSwipe",
            imageHeight: 500,
            horizontalPadding: 0
        ),
        OnboardingPage(
            title: "Free Up Space Fast",
            subtitle: "Find photos, videos, and screenshots that are filling your iPhone.",
            imageName: "OnboardingStorage",
            imageHeight: 470,
            horizontalPadding: 0
        ),
        OnboardingPage(
            title: "Delete Duplicate Photos",
            subtitle: "Keep the best shot and clear extra copies with less effort.",
            imageName: "OnboardingDuplicates",
            imageHeight: 500,
            horizontalPadding: 0
        ),
        OnboardingPage(
            title: "Free Up to 200 GB",
            subtitle: "Clean duplicate shots, old screenshots, and heavy videos taking up space.",
            imageName: "OnboardingSavings",
            imageHeight: 465,
            horizontalPadding: 0
        ),
        OnboardingPage(
            title: "Private by Design",
            subtitle: "Your photos stay on your iPhone. Nothing is uploaded.",
            imageName: "OnboardingPrivacy",
            imageHeight: 460,
            horizontalPadding: 0
        )
    ]
}

#Preview {
    OnboardingView {}
        .preferredColorScheme(.dark)
}
