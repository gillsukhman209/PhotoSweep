import SwiftUI

@main
struct PhotoSweepApp: App {
    @StateObject private var library = PhotoLibraryStore()

    init() {
        AnalyticsService.configure()
        SuperwallBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
        }
    }
}
