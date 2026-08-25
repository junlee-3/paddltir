import Foundation
import Supabase
import Testing
@testable import Paddltir

@MainActor @Suite struct OnboardingViewModelTests {
    private func vm() -> OnboardingViewModel {
        let client = SupabaseClient(supabaseURL: URL(string: Secrets.supabaseURL)!, supabaseKey: Secrets.supabaseAnonKey)
        return OnboardingViewModel(client: client, onFinished: {})
    }

    @Test func createDisabledUntilNameEntered() {
        let m = vm()
        #expect(m.canCreate == false)
        m.clubName = "   "
        #expect(m.canCreate == false)          // whitespace-only is not a name
        m.clubName = "Dragons"
        #expect(m.canCreate == true)
    }

    @Test func codeIsUppercasedAndTrimmedForJoin() {
        let m = vm()
        m.code = "  ab3d ef2h  "
        #expect(m.normalizedCode() == "AB3DEF2H")
        #expect(m.canJoin == true)             // 8 chars after normalizing
        m.code = "ab3"
        #expect(m.canJoin == false)            // too short
    }
}
