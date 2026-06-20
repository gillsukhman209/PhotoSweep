import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    let onComplete: () -> Void

    @State private var selectedPage = 0
    @State private var hasTrackedStart = false

    private let pages = OnboardingPage.allPages
    private let accent = Color(red: 0.30, green: 0.36, blue: 1.0)
    private let accentEnd = Color(red: 0.38, green: 0.20, blue: 1.0)
    private var background: Color {
        colorScheme == .dark ? Color(red: 0.06, green: 0.07, blue: 0.13) : Color(red: 0.94, green: 0.97, blue: 1.0)
    }

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
        .onAppear {
            guard !hasTrackedStart else { return }
            hasTrackedStart = true
            AnalyticsService.track("onboarding_started")
        }
    }

    private var progressBars: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { index in
                GeometryReader { proxy in
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12))
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
        VStack(spacing: 0) {
            Button {
                advance()
            } label: {
                Text(selectedPage == pages.count - 1 ? "Start Cleaning" : "Continue")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
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
        }
    }

    private func fillAmount(for index: Int) -> CGFloat {
        if index < selectedPage { return 1 }
        if index == selectedPage { return 0.78 }
        return 0
    }

    private func advance() {
        if selectedPage == pages.count - 1 {
            AnalyticsService.track("onboarding_completed", properties: [
                "page_count": pages.count
            ])
            onComplete()
        } else {
            AnalyticsService.track("onboarding_step_advanced", properties: [
                "from_page_index": selectedPage,
                "to_page_index": selectedPage + 1
            ])
            withAnimation(.snappy(duration: 0.28)) {
                selectedPage += 1
            }
        }
    }
}

private struct OnboardingPageView: View {
    @Environment(\.colorScheme) private var colorScheme
    let page: OnboardingPage

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 0.07, green: 0.08, blue: 0.10)
    }

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.66) : Color(red: 0.36, green: 0.38, blue: 0.44)
    }

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let compact = height < 620
            let titleSize: CGFloat = compact ? 31 : 38
            let subtitleSize: CGFloat = compact ? 17 : 20
            let imageHeight = min(page.imageHeight, max(250, height * (compact ? 0.48 : 0.57)))

            VStack(spacing: compact ? 12 : 18) {
                Spacer(minLength: compact ? 8 : 18)

                VStack(spacing: compact ? 9 : 14) {
                    Text(page.title)
                        .font(.system(size: titleSize, weight: .black, design: .rounded))
                        .foregroundStyle(primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.56)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(page.subtitle)
                        .font(.system(size: subtitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .lineLimit(4)
                        .minimumScaleFactor(0.68)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, compact ? 16 : 22)

                Image(page.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: imageHeight)
                    .padding(.horizontal, page.horizontalPadding)
                    .accessibilityHidden(true)

                Spacer(minLength: compact ? 4 : 10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
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
}
