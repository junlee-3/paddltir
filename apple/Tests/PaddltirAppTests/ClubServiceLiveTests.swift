// ClubServiceLiveTests.swift
// GATED (PADDLTIR_LIVE_SUPABASE=1): drives the real onboarding RPCs against
// the local Supabase stack. Signs up two throwaway users (local stack has
// email confirmations disabled, so signUp returns a live session), then:
// coach create_club -> paddler join_club by claim. See SupabaseRemoteTests
// for the local-stack setup + the TEST_RUNNER_ env note.
import Foundation
import Supabase
import Testing
@testable import Paddltir

/// A trivial in-memory `AuthLocalStorage` — a separate file-private copy of
/// the one in SupabaseRemoteTests.swift (that type is declared `private`
/// there, so it isn't visible here). See that file's header for why this
/// test doesn't use supabase-swift's Keychain-backed default.
private final class InMemoryAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.lock(); defer { lock.unlock() }; storage[key] = value }
    func retrieve(key: String) throws -> Data? { lock.lock(); defer { lock.unlock() }; return storage[key] }
    func remove(key: String) throws { lock.lock(); defer { lock.unlock() }; storage.removeValue(forKey: key) }
}

@Suite struct ClubServiceLiveTests {
    private func freshClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseURL)!,
            supabaseKey: Secrets.supabaseAnonKey,
            options: SupabaseClientOptions(auth: .init(storage: InMemoryAuthLocalStorage()))
        )
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["PADDLTIR_LIVE_SUPABASE"] == "1"))
    func createClubThenJoinByClaim() async throws {
        // Coach: brand-new user, no club yet.
        let coach = freshClient()
        try await coach.auth.signUp(email: "coach-\(UUID().uuidString)@paddltir.dev", password: "password123")
        let coachService = ClubService(client: coach)
        #expect(try await coachService.currentClubId() == nil)

        let club = try await coachService.createClub(name: "Test Dragons")
        #expect(club.name == "Test Dragons")
        #expect(club.inviteCode.count == 8)              // gen_invite_code() is 8 chars
        #expect(try await coachService.currentClubId() == club.id)

        // No name-claimable paddlers in a fresh club (roster is empty).
        #expect(try await coachService.claimablePaddlers(code: club.inviteCode).isEmpty)

        // Paddler: a second new user joins by code (email-link path, no
        // paddler_id) — succeeds and lands in the same club.
        let paddler = freshClient()
        try await paddler.auth.signUp(email: "pad-\(UUID().uuidString)@paddltir.dev", password: "password123")
        let paddlerService = ClubService(client: paddler)
        try await paddlerService.joinClub(code: club.inviteCode, paddlerId: nil)
        #expect(try await paddlerService.currentClubId() == club.id)
    }
}
