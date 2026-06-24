import Foundation
import Combine
import UIKit
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let dailyReminderIdentifier = "cleanroll.daily-cleanup"
    private let unpaidReminderPrefix = "cleanroll.unpaid-reminder"
    private let dailyReminderEnabledKey = "PhotoSweep.dailyCleanupReminderEnabled"
    private let unpaidReminderEnabledKey = "PhotoSweep.unpaidReminderEnabled"
    private let dailyReminderHourKey = "PhotoSweep.dailyReminderHour"
    private let dailyReminderMinuteKey = "PhotoSweep.dailyReminderMinute"

    private override init() {
        super.init()
    }

    var dailyReminderEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: dailyReminderEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: dailyReminderEnabledKey) }
    }

    var unpaidReminderEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: unpaidReminderEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: unpaidReminderEnabledKey) }
    }

    var dailyReminderDate: Date {
        get {
            let hour: Int
            let minute: Int

            if UserDefaults.standard.object(forKey: dailyReminderHourKey) == nil {
                hour = 19
                minute = 0
            } else {
                hour = UserDefaults.standard.integer(forKey: dailyReminderHourKey)
                minute = UserDefaults.standard.integer(forKey: dailyReminderMinuteKey)
            }

            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = hour
            components.minute = minute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            UserDefaults.standard.set(components.hour ?? 19, forKey: dailyReminderHourKey)
            UserDefaults.standard.set(components.minute ?? 0, forKey: dailyReminderMinuteKey)
        }
    }

    func configure() {
        center.delegate = self
        Task {
            await refreshAuthorizationStatus()
            rescheduleEnabledNotifications()
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestPermission(source: String) async -> Bool {
        AnalyticsService.track("notification_permission_prompt_shown", properties: [
            "source": source
        ])

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            AnalyticsService.track("notification_permission_result", properties: [
                "source": source,
                "granted": granted
            ])
            return granted
        } catch {
            await refreshAuthorizationStatus()
            AnalyticsService.track("notification_permission_failed", properties: [
                "source": source,
                "error": error.localizedDescription
            ])
            return false
        }
    }

    func setDailyReminderEnabled(_ isEnabled: Bool) async {
        dailyReminderEnabled = isEnabled

        guard isEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
            AnalyticsService.track("notification_settings_changed", properties: [
                "daily_cleanup_reminder": false
            ])
            return
        }

        if await ensurePermission(source: "daily_cleanup_toggle") {
            scheduleDailyCleanupReminder()
        } else {
            dailyReminderEnabled = false
        }

        AnalyticsService.track("notification_settings_changed", properties: [
            "daily_cleanup_reminder": dailyReminderEnabled
        ])
    }

    func setUnpaidReminderEnabled(_ isEnabled: Bool) async {
        unpaidReminderEnabled = isEnabled
        if !isEnabled {
            cancelUnpaidReminders()
        } else if !(await ensurePermission(source: "comeback_reminder_toggle")) {
            unpaidReminderEnabled = false
        }
        AnalyticsService.track("notification_settings_changed", properties: [
            "unpaid_reminder": unpaidReminderEnabled
        ])
    }

    func updateDailyReminderTime(_ date: Date) {
        dailyReminderDate = date
        if dailyReminderEnabled {
            scheduleDailyCleanupReminder()
        }
        AnalyticsService.track("notification_settings_changed", properties: [
            "daily_reminder_time": formattedTime(date)
        ])
    }

    func rescheduleEnabledNotifications() {
        if dailyReminderEnabled {
            scheduleDailyCleanupReminder()
        }

        if SuperwallBootstrap.hasProAccess {
            cancelUnpaidReminders()
        }
    }

    func schedulePaywallAbandonedReminders(source: String) {
        guard unpaidReminderEnabled, !SuperwallBootstrap.hasProAccess else {
            cancelUnpaidReminders()
            return
        }

        Task {
            guard await ensurePermission(source: "paywall_abandoned") else { return }
            cancelUnpaidReminders()

            scheduleOneShotReminder(
                identifier: "\(unpaidReminderPrefix).24h",
                title: "Your cleanup is waiting",
                body: "Finish clearing photos and free up space in CleanRoll.",
                secondsFromNow: 24 * 60 * 60,
                category: "paywall_abandoned_24h",
                source: source
            )

            scheduleOneShotReminder(
                identifier: "\(unpaidReminderPrefix).72h",
                title: "Keep your camera roll light",
                body: "A quick swipe session can clean up yesterday's clutter.",
                secondsFromNow: 72 * 60 * 60,
                category: "paywall_abandoned_72h",
                source: source
            )
        }
    }

    func cancelUnpaidReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [
            "\(unpaidReminderPrefix).24h",
            "\(unpaidReminderPrefix).72h"
        ])
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        AnalyticsService.track("notification_opened", properties: [
            "identifier": response.notification.request.identifier,
            "category": userInfo["category"] as? String ?? "unknown",
            "source": userInfo["source"] as? String ?? "unknown"
        ])
    }

    private func ensurePermission(source: String) async -> Bool {
        await refreshAuthorizationStatus()

        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await requestPermission(source: source)
        case .denied:
            AnalyticsService.track("notification_permission_denied", properties: [
                "source": source
            ])
            return false
        @unknown default:
            return false
        }
    }

    private func scheduleDailyCleanupReminder() {
        let date = dailyReminderDate
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)

        let content = UNMutableNotificationContent()
        content.title = "CleanRoll check-in"
        content.body = "Spend one minute clearing photos you don't need."
        content.sound = .default
        content.userInfo = [
            "category": "daily_cleanup",
            "source": "daily_reminder"
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
        center.add(request)

        AnalyticsService.track("notification_scheduled", properties: [
            "identifier": dailyReminderIdentifier,
            "category": "daily_cleanup",
            "time": formattedTime(date)
        ])
    }

    private func scheduleOneShotReminder(
        identifier: String,
        title: String,
        body: String,
        secondsFromNow: TimeInterval,
        category: String,
        source: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [
            "category": category,
            "source": source
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsFromNow, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)

        AnalyticsService.track("notification_scheduled", properties: [
            "identifier": identifier,
            "category": category,
            "source": source,
            "seconds_from_now": Int(secondsFromNow)
        ])
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}
