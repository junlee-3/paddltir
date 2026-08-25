import Foundation

/// The three states the whole app tree switches on. `needsClub` means
/// "authenticated, but the profile has no club_id yet" — the onboarding
/// gate. Deliberately tiny and pure so it can be unit-tested without any
/// Supabase client; `SessionController` owns the side effects that feed it.
enum AuthState: Equatable {
    case signedOut
    case needsClub
    case ready(clubID: String)

    static func resolve(hasSession: Bool, clubID: String?) -> AuthState {
        guard hasSession else { return .signedOut }
        guard let clubID else { return .needsClub }
        return .ready(clubID: clubID)
    }
}
