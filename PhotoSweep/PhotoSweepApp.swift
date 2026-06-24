import SwiftUI

@main
@MainActor
struct PhotoSweepApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var library = PhotoLibraryStore()
    @StateObject private var notificationManager = NotificationManager.shared

    init() {
        AnalyticsService.configure()
        SuperwallBootstrap.configure()
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(notificationManager)
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        await notificationManager.refreshAuthorizationStatus()
                        notificationManager.rescheduleEnabledNotifications()
                    }
                }
        }
    }
}
