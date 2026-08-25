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
        let url = URL(string: Secrets.supabaseURL)!
        let key = Secrets.supabaseAnonKey
        let client: SupabaseClient
        #if DEBUG
        if ProcessInfo.processInfo.environment["PADDLTIR_DEBUG_AUTOSIGNIN"] == "1" {
            client = SupabaseClient(supabaseURL: url, supabaseKey: key,
                options: SupabaseClientOptions(auth: .init(storage: InMemoryAuthLocalStorage())))
        } else {
            client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        }
        #else
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        #endif
        self.environment = AppEnvironment(client: client, db: try! AppDatabase.onDisk())
        self.session = SessionController(client: client)
    }
}

#if DEBUG
/// In-memory AuthLocalStorage used ONLY when launched with
/// PADDLTIR_DEBUG_AUTOSIGNIN=1 — the unsigned simulator build can't reliably
/// read a session back from the Keychain, which makes the auto-sign-in hook
/// (SessionController.start) inert. This keeps the session purely in memory
/// for the run so signed-in screens are reachable for screenshots.
private final class InMemoryAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.lock(); defer { lock.unlock() }; storage[key] = value }
    func retrieve(key: String) throws -> Data? { lock.lock(); defer { lock.unlock() }; return storage[key] }
    func remove(key: String) throws { lock.lock(); defer { lock.unlock() }; storage.removeValue(forKey: key) }
}
#endif
