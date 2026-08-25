// apple/Sources/App/AppModel.swift
// Composition root: builds the single SupabaseClient and shares it between
// the sync layer (AppEnvironment) and auth (SessionController), so both talk
// to the same session. Held by PaddltirApp as @State; injected into the
// environment. A failure to open the on-disk DB is unrecoverable at launch.
import Foundation
import Observation
import Supabase

@MainActor @Observable
final class AppModel {
    let environment: AppEnvironment
    let session: SessionController

    init() {
        let client = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseURL)!,
            supabaseKey: Secrets.supabaseAnonKey
        )
        self.environment = AppEnvironment(client: client, db: try! AppDatabase.onDisk())
        self.session = SessionController(client: client)
    }
}
