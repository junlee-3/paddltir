import Testing
import PaddltirCore
@testable import Paddltir

@Suite struct SmokeTests {
    @Test func coreLinks() {
        #expect(Boat.standard.capacity == 20)
    }

    @Test func dataLayerLinks() {
        #expect(DataLayerSmoke.ok)
    }
}
