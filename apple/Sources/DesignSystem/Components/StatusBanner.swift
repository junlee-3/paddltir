import SwiftUI

/// Non-blocking status strip (hairline card, danger glyph) for "couldn't sync" and write
/// failures. Optional trailing action (e.g. Retry). Never covers content — callers place it
/// at the top of a screen.
public struct StatusBanner: View {
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    public init(_ message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.message = message; self.actionTitle = actionTitle; self.action = action
    }

    public var body: some View {
        HStack(spacing: DS.Space.s) {
            HStack(spacing: DS.Space.s) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(DS.danger)
                Text(message).font(.dsCaption).foregroundStyle(DS.ink).lineLimit(2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)

            Spacer(minLength: DS.Space.s)
            if let actionTitle, let action {
                Button(actionTitle, action: action).font(.dsCaption.weight(.semibold)).foregroundStyle(DS.accent).buttonStyle(.plain)
            }
        }
        .padding(DS.Space.m)
        .background(DS.surface, in: .rect(cornerRadius: DS.R.ctl))
        .overlay(RoundedRectangle(cornerRadius: DS.R.ctl).stroke(DS.border))
    }
}
