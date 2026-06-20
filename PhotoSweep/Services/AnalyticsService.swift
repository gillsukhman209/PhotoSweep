import Foundation

#if DEBUG
enum AnalyticsService {
    static func configure() {}

    static func track(_ event: String, properties: [String: Any] = [:]) {}
}
#else
import PostHog

enum AnalyticsService {
    private static let fallbackProjectToken = "phc_swDDmppzfnSKMexbTqiKNWyXG2L4kPRRvKyD2o6mEaz4"
    private static let fallbackHost = "https://us.i.posthog.com"
    private static var isConfigured = false

    static func configure() {
        guard !isConfigured else { return }

        let bundleToken = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_PROJECT_TOKEN") as? String
        let token = (bundleToken ?? fallbackProjectToken).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }

        let bundleHost = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String
        let host = (bundleHost ?? fallbackHost).trimmingCharacters(in: .whitespacesAndNewlines)

        let config = PostHogConfig(projectToken: token, host: host.isEmpty ? fallbackHost : host)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        config.sessionReplay = false
        config.flushAt = 10

        PostHogSDK.shared.setup(config)
        isConfigured = true

        track("app_opened", properties: appProperties)
    }

    static func track(_ event: String, properties: [String: Any] = [:]) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture(event, properties: sanitized(properties.merging(appProperties) { current, _ in current }))
    }

    private static var appProperties: [String: Any] {
        [
            "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "build_number": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "platform": "ios"
        ]
    }

    private static func sanitized(_ properties: [String: Any]) -> [String: Any] {
        properties.compactMapValues { value in
            switch value {
            case let string as String:
                string
            case let int as Int:
                int
            case let double as Double:
                double
            case let bool as Bool:
                bool
            case let date as Date:
                ISO8601DateFormatter().string(from: date)
            default:
                nil
            }
        }
    }
}
#endif
