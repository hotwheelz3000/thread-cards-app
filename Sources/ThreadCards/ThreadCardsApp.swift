import SwiftUI

@main
struct ThreadCardsApp: App {
    init() {
        AppLog.installCrashHandlers()
        Theme.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
