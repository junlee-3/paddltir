import SwiftUI
import PaddltirCore

@main
struct PaddltirApp: App {
    @State private var app = AppModel()

    init() {
        FontRegistration.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(app.session)
                .environment(app.environment)
                .preferredColorScheme(.light)
                .task { await app.session.start() }
        }
    }
}
