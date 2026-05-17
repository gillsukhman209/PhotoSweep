import Foundation
import SuperwallKit

enum SuperwallBootstrap {
    private static let fallbackPublicAPIKey = "pk_ShVl3C2UpBwMOhrhtMSbu"

    static var hasActiveSubscription: Bool {
        guard configure(), Superwall.isInitialized else { return false }
        return Superwall.shared.subscriptionStatus.isActive
    }

    @discardableResult
    static func configure() -> Bool {
        guard !Superwall.isInitialized else { return true }

        let bundleAPIKey = Bundle.main.object(forInfoDictionaryKey: "SUPERWALL_PUBLIC_API_KEY") as? String
        let apiKey = (bundleAPIKey ?? fallbackPublicAPIKey).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            return false
        }

        Superwall.configure(apiKey: apiKey)
        return Superwall.isInitialized
    }

    static func register(placement: String, feature: @escaping () -> Void) {
        let runFeature = {
            DispatchQueue.main.async {
                feature()
            }
        }

        guard configure(), Superwall.isInitialized else {
            AnalyticsService.track("paywall_unavailable", properties: [
                "placement": placement
            ])
            runFeature()
            return
        }

        AnalyticsService.track("paywall_requested", properties: [
            "placement": placement
        ])
        Superwall.shared.register(placement: placement) {
            runFeature()
        }
    }

    static func requireActiveSubscription(
        placement: String,
        params: [String: Any]? = nil,
        onComplete: @escaping () -> Void = {},
        feature: @escaping () -> Void
    ) {
        final class CompletionBox {
            private var hasCompleted = false

            func complete(_ action: @escaping () -> Void) {
                guard !hasCompleted else { return }
                hasCompleted = true
                DispatchQueue.main.async {
                    action()
                }
            }
        }

        let completionBox = CompletionBox()

        let finish = {
            completionBox.complete(onComplete)
        }

        let unlockIfSubscribed = {
            guard hasActiveSubscription else {
                return
            }

            completionBox.complete {
                onComplete()
                feature()
            }
        }

        let runFeatureIfSubscribedOrFinish = {
            guard hasActiveSubscription else {
                finish()
                return
            }

            unlockIfSubscribed()
        }

        guard configure(), Superwall.isInitialized else {
            AnalyticsService.track("paywall_unavailable", properties: [
                "placement": placement
            ])
            finish()
            return
        }

        guard !Superwall.shared.subscriptionStatus.isActive else {
            unlockIfSubscribed()
            return
        }

        let handler = PaywallPresentationHandler()
        handler.onPresent { info in
            AnalyticsService.track("paywall_shown", properties: paywallProperties(placement: placement, info: info))
        }
        handler.onDismiss { _, result in
            switch result {
            case .purchased, .restored:
                AnalyticsService.track(result == .restored ? "paywall_restored" : "paywall_purchased", properties: [
                    "placement": placement
                ])
                unlockIfSubscribed()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    unlockIfSubscribed()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    finish()
                }
            case .declined:
                AnalyticsService.track("paywall_dismissed", properties: [
                    "placement": placement,
                    "result": "declined"
                ])
                finish()
            }
        }
        handler.onSkip { reason in
            AnalyticsService.track("paywall_skipped", properties: [
                "placement": placement,
                "reason": String(describing: reason)
            ])
            finish()
        }
        handler.onError { error in
            AnalyticsService.track("paywall_error", properties: [
                "placement": placement,
                "error": String(describing: error)
            ])
            finish()
        }

        AnalyticsService.track("paywall_requested", properties: [
            "placement": placement
        ])
        Superwall.shared.register(
            placement: placement,
            params: params,
            handler: handler
        ) {
            runFeatureIfSubscribedOrFinish()
        }
    }

    private static func paywallProperties(placement: String, info: PaywallInfo) -> [String: Any] {
        [
            "placement": placement,
            "paywall_identifier": info.identifier,
            "paywall_name": info.name,
            "presented_by": info.presentedBy
        ]
    }
}
