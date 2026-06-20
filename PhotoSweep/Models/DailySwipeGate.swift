import Foundation

enum LifetimeSwipeGate {
    static let freeSwipeLimit = 15

    static func canUseFreeSwipes(
        usedCount: Int,
        requestedCount: Int,
        limit: Int = freeSwipeLimit
    ) -> Bool {
        requestedCount > 0 && max(0, usedCount) + requestedCount <= limit
    }
}
