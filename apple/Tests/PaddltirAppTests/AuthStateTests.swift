import Testing
@testable import Paddltir

@Suite struct AuthStateTests {
    @Test func noSessionIsSignedOut() {
        #expect(AuthState.resolve(hasSession: false, clubID: nil) == .signedOut)
        // A stale clubID without a session is still signed out.
        #expect(AuthState.resolve(hasSession: false, clubID: "c-1") == .signedOut)
    }

    @Test func sessionWithoutClubNeedsClub() {
        #expect(AuthState.resolve(hasSession: true, clubID: nil) == .needsClub)
    }

    @Test func sessionWithClubIsReady() {
        #expect(AuthState.resolve(hasSession: true, clubID: "club-1") == .ready(clubID: "club-1"))
    }
}
