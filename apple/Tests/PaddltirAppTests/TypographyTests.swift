import Testing
import CoreText
@testable import Paddltir

@Suite struct TypographyTests {
    @Test func interTightRegisters() {
        FontRegistration.registerAll()
        let f = CTFontCreateWithName("InterTight-SemiBold" as CFString, 17, nil)
        let name = CTFontCopyPostScriptName(f) as String
        #expect(name.contains("InterTight"), "resolved \(name) — Inter Tight not registered/bundled")
    }
}
