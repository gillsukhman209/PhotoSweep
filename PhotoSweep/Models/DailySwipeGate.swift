import Foundation

enum DailySwipeGate {
    static let freeSwipeLimit = 5

    static func dayKey(
        for date: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func normalizedCount(
        storedCount: Int,
        storedDay: String,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> (count: Int, day: String) {
        let today = dayKey(for: now, calendar: calendar)
        guard storedDay == today else {
            return (0, today)
        }

        return (max(0, storedCount), storedDay)
    }

    static func canUseFreeSwipes(
        currentCount: Int,
        requestedCount: Int,
        limit: Int = freeSwipeLimit
    ) -> Bool {
        requestedCount > 0 && currentCount + requestedCount <= limit
    }
}
