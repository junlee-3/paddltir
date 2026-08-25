import SwiftUI
#if DEBUG
import GRDB
#endif

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
                .task { await environment.observeClub() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await environment.sync() } }
                }
        }
    }
}

/// App navigation shell — a `TabView` on iOS (Schedule / Crews / Squad, plus a DEBUG-only
/// Design tab exercising the whole design system), and a `NavigationSplitView` on macOS.
private struct MainShell: View {
    @Environment(AppModel.self) private var app
    @Environment(AppEnvironment.self) private var environment

    #if os(iOS)
    @State private var selection: Int = {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["PADDLTIR_DEBUG_TAB"], let tag = Int(raw) { return tag }
        #endif
        return 0
    }()
    #endif

    #if DEBUG
    @State private var debugOpenHeat = ProcessInfo.processInfo.environment["PADDLTIR_DEBUG_OPEN_FIRST_HEAT"] == "1"
    #endif

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            SidebarList(selection: $macSelection)
        } detail: {
            macDetail
        }
        .tint(DS.accent)
        .safeAreaInset(edge: .top) { syncBanner }
        #else
        TabView(selection: $selection) {
            ScheduleView(db: app.environment.db)
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(0)
            CrewsView(db: app.environment.db)
                .tabItem { Label("Crews", systemImage: "figure.water.fitness") }
                .tag(1)
            SquadView(db: app.environment.db)
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
        .safeAreaInset(edge: .top) { syncBanner }
        #if DEBUG && os(iOS)
        .fullScreenCover(isPresented: $debugOpenHeat) { DebugFirstHeatEditor() }
        #endif
        #endif
    }

    /// Non-blocking "couldn't sync" strip shown over either platform's shell whenever the
    /// last `AppEnvironment.sync()` failed. Cached data stays on screen underneath — this
    /// never gates or replaces content.
    @ViewBuilder private var syncBanner: some View {
        if environment.lastSyncError != nil {
            StatusBanner("Couldn't sync — showing saved data.", actionTitle: "Retry") {
                Task { await environment.sync() }
            }
            .padding(.horizontal, DS.Space.l)
        }
    }

    #if os(macOS)
    @State private var macSelection: SidebarSection? = .schedule

    @ViewBuilder private var macDetail: some View {
        switch macSelection ?? .schedule {
        case .schedule: ScheduleView(db: app.environment.db)
        case .crews: CrewsView(db: app.environment.db)
        case .squad: SquadView(db: app.environment.db)
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

#if DEBUG
/// Screenshot-only deep link: resolves the first heat (by `sort_order`) and
/// opens the lineup editor directly on it, bypassing the normal
/// Schedule -> race -> heat navigation. Gated by `PADDLTIR_DEBUG_OPEN_FIRST_HEAT=1`.
private struct DebugFirstHeatEditor: View {
    @Environment(AppModel.self) private var app
    @State private var race: Race?

    var body: some View {
        NavigationStack {
            if let race {
                LineupEditorView(race: race, db: app.environment.db)
            } else {
                ProgressView()
            }
        }
        .task {
            // Observe rather than read once: on a fresh install the first race only arrives with sync.
            let firstRace = ValueObservation.tracking { db in try Race.order(Column("sort_order")).fetchOne(db) }
            do {
                for try await candidate in firstRace.values(in: app.environment.db.dbQueue) {
                    if let candidate { race = candidate; break }
                }
            } catch { /* DEBUG harness only — leave the spinner */ }
        }
    }
}
#endif
