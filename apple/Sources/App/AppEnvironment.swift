// AppEnvironment.swift
// App-wide holder wiring the on-disk GRDB store to the shared Supabase
// client through SyncEngine.
//
// One instance is meant to be created once (by `AppModel`, the composition
// root, which builds the shared `SupabaseClient`) and injected down the view
// tree via SwiftUI's Observation-based environment (`.environment(_:)` /
// `@Environment(AppEnvironment.self)`) so views can call `sync()` — e.g. from
// `RootView`'s `.task` on launch and `.onChange(of: scenePhase)` on
// foreground — without threading the database/remote/engine through every
// initializer.
//
// Sync failures are captured in `lastSyncError` rather than thrown further
// — a stale local cache is a perfectly usable degraded state (this is an
// offline-first app), and the next successful sync self-heals it.

import Foundation
import Observation
import Supabase

@MainActor @Observable
final class AppEnvironment {
    let client: SupabaseClient
    let db: AppDatabase
    private let syncEngine: SyncEngine

    /// `true` while a `sync()` call is in flight. Views can use this to show
    /// a subtle syncing indicator.
    private(set) var isSyncing = false

    /// The error from the most recently *failed* `sync()`, if any — cleared
    /// on the next successful sync. Non-fatal; see file header.
    private(set) var lastSyncError: (any Error)?

    /// Bumped after each successful sync so views that loaded from a
    /// then-empty cache can reload once pulled data lands. (The feature
    /// screens load once via `.task`; they observe this to refresh.)
    private(set) var syncGeneration = 0

    init(client: SupabaseClient, db: AppDatabase) {
        self.client = client
        self.db = db
        self.syncEngine = SyncEngine(db: db, remote: SupabaseRemote(client: client))
    }

    /// Pulls remote changes into GRDB and drains the local outbox. Safe to
    /// call whenever — signed out or club-less callers no-op harmlessly,
    /// since `SyncEngine.syncAll()` itself no-ops until `RemoteStore.clubID`
    /// resolves (see SyncEngine.swift), and overlapping calls are coalesced
    /// by the `isSyncing` guard below rather than run concurrently.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await syncEngine.syncAll()
            lastSyncError = nil
            syncGeneration += 1
        } catch {
            lastSyncError = error
        }
    }
}
