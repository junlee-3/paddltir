import SwiftUI
import PaddltirCore

@main
struct PaddltirApp: App {
    init() {
        FontRegistration.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
