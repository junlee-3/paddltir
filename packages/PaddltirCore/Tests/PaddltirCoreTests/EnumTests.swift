import Testing
@testable import PaddltirCore

@Suite struct EnumTests {
    @Test func sidePreferenceMatching() {
        #expect(SidePreference.left.matches(.left))
        #expect(!SidePreference.left.matches(.right))
        #expect(SidePreference.either.matches(.left) && SidePreference.either.matches(.right))
    }
    @Test func seatPreferenceSection() {
        #expect(SeatPreference.engine.section == .engine)
        #expect(SeatPreference.none.section == nil)
    }
    @Test func rolesThatMayPaddle() {
        #expect(BoatRole.paddler.mayPaddle && BoatRole.drummer.mayPaddle && !BoatRole.sweep.mayPaddle)
    }
    @Test func rawValuesAreLowercase() {
        #expect(Side.left.rawValue == "left" && Gender.female.rawValue == "female" && Section.sprint.rawValue == "sprint")
    }
}
