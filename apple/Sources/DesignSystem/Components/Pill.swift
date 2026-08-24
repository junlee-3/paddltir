import SwiftUI

/// Small rounded chip used for tags, statuses, and counts.
public struct Pill: View {
    let text: String
    var tint: Color?
    public init(_ t: String, tint: Color? = nil) { text = t; self.tint = tint }
    public var body: some View {
        Text(text)
            .font(.dsCaption)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(tint ?? DS.surface2, in: .rect(cornerRadius: DS.R.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.R.sm).stroke(tint == nil ? DS.border : .clear))
            .foregroundStyle(tint == nil ? DS.ink : DS.accent)
    }
}
