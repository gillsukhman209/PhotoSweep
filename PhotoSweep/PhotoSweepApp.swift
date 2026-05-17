import SwiftUI
import SuperwallKit

@main
struct PhotoSweepApp: App {
    @StateObject private var library = PhotoLibraryStore()

    init() {
        SuperwallBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
        }
    }
}
