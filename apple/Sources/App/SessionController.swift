// apple/Sources/App/SessionController.swift
// Owns auth-state observation. Subscribes to supabase-swift's
// authStateChanges; each event resolves the current club_id via ClubService
// and republishes AuthState (through the pure reducer). Onboarding actions
// (create/join) call ClubService directly, then refreshClub() to flip the
// gate. @MainActor so `state` mutates on the main thread for SwiftUI.
import Foundation
import Observation
import Supabase

@MainActor @Observable
final class SessionController {
    private(set) var state: AuthState = .signedOut
    private let client: SupabaseClient
    private let clubs: ClubService

    init(client: SupabaseClient) {
        self.client = client
        self.clubs = ClubService(client: client)
    }

    /// Long-lived: consumes the auth event stream until the task is
    /// cancelled (RootView owns the `.task`). Yields `.initialSession`
    /// immediately on subscribe, so the first launch state resolves here.
    func start() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["PADDLTIR_DEBUG_AUTOSIGNIN"] == "1" {
            if (try? await client.auth.session) == nil {
                try? await client.auth.signIn(email: "coach@paddltir.dev", password: "password123")
                await refreshClub()
            }
        }
        #endif
        for await (_, session) in client.auth.authStateChanges {
            await resolve(session: session)
        }
    }

    /// Re-check the club after an onboarding action changed it.
    func refreshClub() async {
        let session = try? await client.auth.session
        await resolve(session: session)
    }

    func signOut() async {
        try? await client.auth.signOut()
        apply(hasSession: false, clubID: nil)
    }

    private func resolve(session: Session?) async {
        guard session != nil else { apply(hasSession: false, clubID: nil); return }
        let clubID = try? await clubs.currentClubId()
        apply(hasSession: true, clubID: clubID ?? nil)
    }

    /// Pure state transition — the unit-tested seam.
    func apply(hasSession: Bool, clubID: String?) {
        state = AuthState.resolve(hasSession: hasSession, clubID: clubID)
    }

    #if DEBUG
    /// Renders a fixed state for previews/screenshots without any network.
    init(previewState: AuthState) {
        self.client = SupabaseClient(
            supabaseURL: URL(string: Secrets.supabaseURL)!,
            supabaseKey: Secrets.supabaseAnonKey
        )
        self.clubs = ClubService(client: client)
        self.state = previewState
    }
    #endif
}
