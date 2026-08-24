import CoreText
import Foundation

/// Registers the bundled Inter Tight static weights with CoreText at process scope
/// so `Font.custom` can resolve them by PostScript name.
enum FontRegistration {
    static func registerAll() {
        let names = [
            "InterTight-Regular",
            "InterTight-Medium",
            "InterTight-SemiBold",
            "InterTight-Bold",
            "InterTight-ExtraBold",
        ]
        for n in names {
            guard let url = Bundle.main.url(forResource: n, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
