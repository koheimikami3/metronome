import SwiftUI

@main
struct MetronomeApp: App {
    init() {
        AnalyticsSetup.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
