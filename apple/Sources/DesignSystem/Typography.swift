import SwiftUI

public enum PaddltirFont {
    public enum W {
        case regular, medium, semibold, bold, heavy
        var name: String {
            switch self {
            case .regular: "InterTight-Regular"
            case .medium: "InterTight-Medium"
            case .semibold: "InterTight-SemiBold"
            case .bold: "InterTight-Bold"
            case .heavy: "InterTight-ExtraBold"
            }
        }
    }

    /// Inter Tight at a size/weight; falls back to system if the custom face is unavailable.
    public static func font(_ size: CGFloat, _ w: W = .regular) -> Font { .custom(w.name, size: size) }
}

public extension Font {
    static let dsLargeTitle = PaddltirFont.font(30, .heavy)      // screen titles (tracking -.02 applied at call site)
    static let dsTitle      = PaddltirFont.font(22, .bold)
    static let dsHeadline   = PaddltirFont.font(17, .semibold)
    static let dsBody       = PaddltirFont.font(16, .regular)
    static let dsCallout    = PaddltirFont.font(15, .medium)
    static let dsSubhead    = PaddltirFont.font(14, .medium)
    static let dsFootnote   = PaddltirFont.font(13, .regular)
    static let dsCaption    = PaddltirFont.font(12, .medium)
    static let dsMicro      = PaddltirFont.font(11, .semibold)   // UPPERCASE tracked micro-labels
    static func dsNumber(_ size: CGFloat, _ w: PaddltirFont.W = .bold) -> Font {
        PaddltirFont.font(size, w)   // pair with .monospacedDigit() at the call site
    }
}
