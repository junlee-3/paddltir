import SwiftUI

public enum DS {
    // colours (asset catalog, light-only for now)
    public static let bg = Color("bg"); public static let surface = Color("surface")
    public static let surface2 = Color("surface2"); public static let ink = Color("ink")
    public static let ink2 = Color("ink2"); public static let ink3 = Color("ink3")
    public static let border = Color("border"); public static let border2 = Color("border2")
    public static let primary = Color("primary"); public static let onPrimary = Color("onPrimary")
    public static let accent = Color("accent"); public static let good = Color("good"); public static let danger = Color("danger")
    public static let maleFill = Color("maleFill"); public static let maleBorder = Color("maleBorder")
    public static let femaleFill = Color("femaleFill"); public static let femaleBorder = Color("femaleBorder")
    // metrics
    public enum R {
        public static let card: CGFloat = 12
        public static let ctl: CGFloat = 8
        public static let sm: CGFloat = 6
        public static let tile: CGFloat = 8
    }
    public enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
    }
    public static let hairline: CGFloat = 1
    // thresholds mirror PaddltirCore.Thresholds for HUD colouring
}
