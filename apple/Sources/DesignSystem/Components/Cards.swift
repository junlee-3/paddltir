import SwiftUI

/// White surface container with a 1px hairline border and a subtle drop shadow.
public struct HairlineCard<Content: View>: View {
    var padding: CGFloat
    @ViewBuilder var content: Content
    public init(padding: CGFloat = DS.Space.l, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    public var body: some View {
        content
            .padding(padding)
            .background(DS.surface, in: .rect(cornerRadius: DS.R.card))
            .overlay(RoundedRectangle(cornerRadius: DS.R.card).stroke(DS.border))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}
