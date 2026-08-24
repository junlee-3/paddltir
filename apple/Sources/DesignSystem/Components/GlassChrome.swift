import SwiftUI

// The ONLY place `.glassEffect()` is used in the app. iOS/macOS 26 ship a real
// Liquid Glass API on SwiftUICore.View:
//
//   nonisolated public func glassEffect(
//       _ glass: SwiftUICore.Glass = .regular,
//       in shape: some Shape = DefaultGlassEffectShape()
//   ) -> some SwiftUICore.View
//
// confirmed against the installed Xcode 26.1 / iOS 26.1 SDK
// (SwiftUICore.swiftmodule/arm64-apple-ios-simulator.swiftinterface). That
// matches the brief's call site exactly, so no fallback is needed here.

/// Rounded content container rendered with genuine Liquid Glass.
public struct GlassContainer<Content: View>: View {
    var radius: CGFloat
    @ViewBuilder var content: Content
    public init(radius: CGFloat = DS.R.card, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }
    public var body: some View {
        content
            .padding(DS.Space.m)
            .glassEffect(.regular, in: .rect(cornerRadius: radius))   // iOS/macOS 26 Liquid Glass
    }
}

/// Full-bleed glass bar for toolbars / floating chrome, grouped in a
/// `GlassEffectContainer` so adjacent glass shapes merge and morph together.
public struct GlassBar<Content: View>: View {
    var radius: CGFloat
    @ViewBuilder var content: Content
    public init(radius: CGFloat = DS.R.ctl, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }
    public var body: some View {
        GlassEffectContainer {
            content
                .padding(.horizontal, DS.Space.l)
                .padding(.vertical, DS.Space.s)
                .glassEffect(.regular, in: .rect(cornerRadius: radius))
        }
    }
}
