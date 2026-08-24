import SwiftUI

/// Small rounded chip used for tags, statuses, and counts.
public struct Pill: View {
    let text: String
    var tint: Color?
    var foreground: Color?
    public init(_ t: String, tint: Color? = nil, foreground: Color? = nil) {
        text = t
        self.tint = tint
        self.foreground = foreground
    }
    public var body: some View {
        Text(text)
            .font(.dsCaption)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(tint ?? DS.surface2, in: .rect(cornerRadius: DS.R.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.R.sm).stroke(tint == nil ? DS.border : .clear))
            .foregroundStyle(foreground ?? (tint == nil ? DS.ink : DS.accent))
    }
}
