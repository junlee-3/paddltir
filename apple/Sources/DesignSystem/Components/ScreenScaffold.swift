import SwiftUI

/// Shared full-bleed screen background (`DS.bg`) with a large Inter Tight title and an
/// optional note, used by the feature placeholders and any screen that just needs a
/// consistent header over the design system background.
public struct ScreenScaffold<Content: View>: View {
    let title: String
    var note: String?
    @ViewBuilder var content: Content

    public init(_ title: String, note: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            DS.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: DS.Space.m) {
                Text(title)
                    .font(.dsLargeTitle)
                    .tracking(-0.2)
                    .foregroundStyle(DS.ink)
                if let note {
                    Text(note)
                        .font(.dsBody)
                        .foregroundStyle(DS.ink2)
                }
                content
            }
            .padding(DS.Space.xl)
        }
    }
}

public extension ScreenScaffold where Content == EmptyView {
    init(_ title: String, note: String? = nil) {
        self.init(title, note: note) { EmptyView() }
    }
}
