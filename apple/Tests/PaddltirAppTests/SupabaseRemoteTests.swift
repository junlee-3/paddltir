// SupabaseRemoteTests.swift
// GATED integration test: exercises SupabaseRemote against a real, local
// Supabase stack (not a fake). SyncEngineTests' FakeRemote-backed suite
// remains the always-on gate; this test additionally verifies the real
// supabase-swift wire format end-to-end, which nothing else in this repo
// does.
//
// Requires, from the repo root:
//   1. `supabase start` (needs Docker/OrbStack) — `supabase status` prints
//      the API URL + anon key, already filled into the git-ignored
//      `apple/Sources/App/Secrets.swift` for local dev.
//   2. `supabase db reset` (applies migrations and supabase/seed.sql, per
//      supabase/config.toml), then
//      `psql "$DB_URL" -f supabase/seed_dev.sql` (or, without a local
//      `psql` client, pipe the file into the db container's own psql:
//      `docker exec -i supabase_db_paddltir psql -U postgres -d postgres
//      < supabase/seed_dev.sql`) to load the demo coach account and the
//      bulk of the paddler/crew/heat rows this test asserts on.
//
// Ran successfully against the local stack while implementing this test
// (24 paddlers, 1 crew, 3 heats seeded) — see task-6-report.md. If the local
// stack isn't up when this suite runs, this test fails with a connection
// error rather than being silently skipped — that's an accepted tradeoff per
// Task 6's brief (mark `@Test(.disabled("requires local Supabase stack"))`
// instead if the stack won't come up at all; see the report for whether
// that applies here).
//
// `InMemoryAuthLocalStorage` below works around a real gotcha discovered
// while writing this test: supabase-swift's default `AuthLocalStorage` is
// Keychain-backed, and this test target builds with
// `CODE_SIGNING_ALLOWED: NO` (see project.yml) — an unsigned XCTest bundle
// can write to the Keychain but then fail to read the same item back,
// so `client.auth.signIn(...)` would succeed while the very next
// `client.auth.session` access threw `AuthError.sessionMissing` (confirmed
// by reproducing it directly). Swapping in a plain in-memory store sidesteps
// Keychain entirely — this test only needs the session to survive its own
// duration, not across runs.

import Foundation
import GRDB
import Supabase
import Testing
@testable import Paddltir

/// A trivial in-memory `AuthLocalStorage` — see file header for why this
/// test doesn't use supabase-swift's Keychain-backed default.
private final class InMemoryAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    func store(key: String, value: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    func retrieve(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func remove(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}

@Suite struct SupabaseRemoteTests {
    @Test func syncAllPullsTheLocalStackDemoSeedIntoGRDB() async throws {
        let client = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseURL)!,
            supabaseKey: Secrets.supabaseAnonKey,
            options: SupabaseClientOptions(auth: .init(storage: InMemoryAuthLocalStorage()))
        )
        try await client.auth.signIn(email: "coach@paddltir.dev", password: "password123")

        let remote = SupabaseRemote(client: client)
        let db = try AppDatabase.inMemory()
        try await SyncEngine(db: db, remote: remote).syncAll()

        let paddlerCount = try db.read { db in try PaddlerRow.fetchCount(db) }
        let crewCount = try db.read { db in try Crew.fetchCount(db) }
        let heatCount = try db.read { db in try Heat.fetchCount(db) }

        #expect(paddlerCount >= 20)
        #expect(crewCount >= 1)
        #expect(heatCount >= 3)
    }
}
