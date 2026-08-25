import SwiftUI

/// Top-level gate: switches on `SessionController.state` to show the
/// signed-out auth flow, the no-club onboarding flow, or the main app
/// shell. The ready shell also drives `AppEnvironment.sync()` on launch and
/// whenever the app returns to the foreground.
struct RootView: View {
    @Environment(SessionController.self) private var session
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        switch session.state {
        case .signedOut:
            AuthView()
        case .needsClub:
            OnboardingView()
        case .ready:
            MainShell()
                .task { await environment.sync() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await environment.sync() } }
                }
        }
    }
}

/// App navigation shell — a `TabView` on iOS (Schedule / Crews / Squad, plus a DEBUG-only
/// Design tab exercising the whole design system), and a `NavigationSplitView` on macOS.
private struct MainShell: View {
    #if os(iOS)
    @State private var selection = 0
    #endif

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            SidebarList(selection: $macSelection)
        } detail: {
            macDetail
        }
        .tint(DS.accent)
        #else
        TabView(selection: $selection) {
            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(0)
            CrewsPlaceholder()
                .tabItem { Label("Crews", systemImage: "figure.water.fitness") }
                .tag(1)
            SquadPlaceholder()
                .tabItem { Label("Squad", systemImage: "person.3") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
            #if DEBUG
            DesignSystemGallery()
                .tabItem { Label("Design", systemImage: "paintpalette") }
                .tag(3)
            #endif
        }
        .tint(DS.accent)
        #endif
    }

    #if os(macOS)
    @State private var macSelection: SidebarSection? = .schedule

    @ViewBuilder private var macDetail: some View {
        switch macSelection ?? .schedule {
        case .schedule: ScheduleView()
        case .crews: CrewsPlaceholder()
        case .squad: SquadPlaceholder()
        case .settings: SettingsView()
        }
    }
    #endif
}

#if os(macOS)
private enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case schedule = "Schedule", crews = "Crews", squad = "Squad", settings = "Settings"
    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .schedule: "calendar"
        case .crews: "figure.water.fitness"
        case .squad: "person.3"
        case .settings: "gearshape"
        }
    }
}

/// Simple sidebar listing the three top-level sections.
private struct SidebarList: View {
    @Binding var selection: SidebarSection?
    var body: some View {
        List(SidebarSection.allCases, selection: $selection) { section in
            Label(section.rawValue, systemImage: section.systemImage).tag(section)
        }
        .navigationTitle("Paddltir")
    }
}
#endif
