import Foundation

#if DEBUG
enum SuperwallBootstrap {
    enum RestoreOutcome {
        case restoredProAccess
        case noPurchaseFound
        case failed(String)
    }

    static var hasProAccess: Bool {
        debugLog("hasProAccess=true because Debug builds bypass the paywall")
        return true
    }

    @discardableResult
    static func configure() -> Bool {
        debugLog("configure skipped in Debug; Superwall is disabled")
        return false
    }

    static func register(placement: String, feature: @escaping () -> Void) {
        debugLog("register placement=\(placement) bypassed in Debug; running feature")
        DispatchQueue.main.async {
            feature()
        }
    }

    static func requireProAccess(
        placement: String,
        params: [String: Any]? = nil,
        onComplete: @escaping () -> Void = {},
        feature: @escaping () -> Void
    ) {
        debugLog("requireProAccess placement=\(placement) bypassed in Debug; unlocking feature")
        DispatchQueue.main.async {
            onComplete()
            feature()
        }
    }

    static func presentPaywall(placement: String, source: String) {
        debugLog("presentPaywall placement=\(placement) source=\(source) ignored in Debug")
    }

    static func presentDebugPaywall(placement: String, source: String) {
        debugLog("presentDebugPaywall placement=\(placement) source=\(source) ignored in Debug")
    }

    static func restorePurchases() async -> RestoreOutcome {
        debugLog("restorePurchases ignored in Debug")
        return .restoredProAccess
    }

    private static func debugLog(_ message: String) {
        print("PhotoSweepPaywall \(message)")
    }
}
#else
import SuperwallKit

enum SuperwallBootstrap {
    enum RestoreOutcome {
        case restoredProAccess
        case noPurchaseFound
        case failed(String)
    }

    private static let fallbackPublicAPIKey = "pk_ShVl3C2UpBwMOhrhtMSbu"

    static var hasProAccess: Bool {
        guard configure(), Superwall.isInitialized else {
            debugLog("hasProAccess=false because Superwall is not initialized")
            return false
        }

        let status = Superwall.shared.subscriptionStatus
        debugLog("hasProAccess check status=\(String(describing: status)) isActive=\(status.isActive)")
        return status.isActive
    }

    @discardableResult
    static func configure() -> Bool {
        guard !Superwall.isInitialized else {
            debugLog("configure skipped; Superwall is already initialized")
            return true
        }

        let bundleAPIKey = Bundle.main.object(forInfoDictionaryKey: "SUPERWALL_PUBLIC_API_KEY") as? String
        let apiKey = (bundleAPIKey ?? fallbackPublicAPIKey).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            debugLog("configure failed; API key is empty")
            return false
        }

        Superwall.configure(apiKey: apiKey)

        debugLog("configure complete isInitialized=\(Superwall.isInitialized) apiKeySuffix=\(String(apiKey.suffix(6)))")
        return Superwall.isInitialized
    }

    static func register(placement: String, feature: @escaping () -> Void) {
        let runFeature = {
            DispatchQueue.main.async {
                feature()
            }
        }

        guard configure(), Superwall.isInitialized else {
            debugLog("register placement=\(placement) unavailable; running feature without Superwall")
            AnalyticsService.track("paywall_unavailable", properties: [
                "placement": placement
            ])
            runFeature()
            return
        }

        debugLog("register placement=\(placement)")
        AnalyticsService.track("paywall_requested", properties: [
            "placement": placement
        ])
        Superwall.shared.register(placement: placement) {
            debugLog("register feature closure fired placement=\(placement)")
            runFeature()
        }
    }

    static func requireProAccess(
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
            guard hasProAccess else {
                return
            }

            completionBox.complete {
                onComplete()
                feature()
            }
        }

        let runFeatureIfSubscribedOrFinish = {
            guard hasProAccess else {
                finish()
                return
            }

            unlockIfSubscribed()
        }

        guard configure(), Superwall.isInitialized else {
            debugLog("requireProAccess placement=\(placement) unavailable; finishing without feature")
            AnalyticsService.track("paywall_unavailable", properties: [
                "placement": placement
            ])
            finish()
            return
        }

        let status = Superwall.shared.subscriptionStatus
        debugLog("requireProAccess placement=\(placement) status=\(String(describing: status)) isActive=\(status.isActive) params=\(params ?? [:])")

        guard !status.isActive else {
            debugLog("requireProAccess placement=\(placement) already active; unlocking")
            unlockIfSubscribed()
            return
        }

        let handler = PaywallPresentationHandler()
        handler.onPresent { info in
            debugLog("paywall onPresent placement=\(placement) id=\(info.identifier) name=\(info.name) presentedBy=\(info.presentedBy)")
            AnalyticsService.track("paywall_shown", properties: paywallProperties(placement: placement, info: info))
        }
        handler.onDismiss { _, result in
            debugLog("paywall onDismiss placement=\(placement) result=\(String(describing: result))")
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
            debugLog("paywall onSkip placement=\(placement) reason=\(String(describing: reason))")
            AnalyticsService.track("paywall_skipped", properties: [
                "placement": placement,
                "reason": String(describing: reason)
            ])
            finish()
        }
        handler.onError { error in
            debugLog("paywall onError placement=\(placement) error=\(String(describing: error))")
            AnalyticsService.track("paywall_error", properties: [
                "placement": placement,
                "error": String(describing: error)
            ])
            finish()
        }

        AnalyticsService.track("paywall_requested", properties: [
            "placement": placement
        ])

        debugLog("registering gated placement=\(placement)")
        Superwall.shared.register(
            placement: placement,
            params: params,
            handler: handler
        ) {
            debugLog("register feature closure fired placement=\(placement); checking entitlement before feature")
            runFeatureIfSubscribedOrFinish()
        }
    }

    static func presentPaywall(placement: String, source: String) {
        debugLog("presentPaywall placement=\(placement) source=\(source)")
        requireProAccess(
            placement: placement,
            params: [
                "source": source
            ],
            feature: {}
        )
    }

    static func presentDebugPaywall(placement: String, source: String) {
        presentPaywall(placement: placement, source: source)
    }

    static func restorePurchases() async -> RestoreOutcome {
        guard configure(), Superwall.isInitialized else {
            debugLog("restorePurchases unavailable; Superwall not initialized")
            AnalyticsService.track("restore_purchases_unavailable")
            return .failed("Purchases are not available right now. Please try again later.")
        }

        debugLog("restorePurchases started")
        AnalyticsService.track("restore_purchases_started")

        let result = await Superwall.shared.restorePurchases()
        debugLog("restorePurchases result=\(String(describing: result)) status=\(String(describing: Superwall.shared.subscriptionStatus))")
        switch result {
        case .restored:
            if hasProAccess {
                AnalyticsService.track("restore_purchases_restored")
                return .restoredProAccess
            } else {
                AnalyticsService.track("restore_purchases_not_found")
                return .noPurchaseFound
            }
        case .failed(let error):
            let message = error?.localizedDescription ?? "Restore failed. Please try again."
            AnalyticsService.track("restore_purchases_failed", properties: [
                "error": message
            ])
            return .failed(message)
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

    private static func debugLog(_ message: String) {
        print("PhotoSweepPaywall \(message)")
    }
}
#endif
