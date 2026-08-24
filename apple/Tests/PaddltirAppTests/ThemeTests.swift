import Testing
import SwiftUI
@testable import Paddltir

@Suite struct ThemeTests {
    @Test func accentResolves() {
        #if canImport(UIKit)
        let c = UIColor(DS.accent)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 0.051) < 0.02 && abs(g - 0.451) < 0.02, "accent wrong: \(r),\(g),\(b)")
        #endif
    }
}
