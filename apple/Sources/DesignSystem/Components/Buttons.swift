import SwiftUI

/// Filled primary action button — `DS.primary` background, `DS.onPrimary` text.
public struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    public init(_ t: String, action: @escaping () -> Void) { title = t; self.action = action }
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.dsHeadline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .foregroundStyle(DS.onPrimary)
        .background(DS.primary, in: .rect(cornerRadius: DS.R.ctl))
        .buttonStyle(.plain)
    }
}

/// Outlined secondary action button — `DS.surface` background, `DS.border` hairline stroke.
public struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    public init(_ t: String, action: @escaping () -> Void) { title = t; self.action = action }
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.dsHeadline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .foregroundStyle(DS.ink)
        .background(DS.surface, in: .rect(cornerRadius: DS.R.ctl))
        .overlay(RoundedRectangle(cornerRadius: DS.R.ctl).stroke(DS.border))
        .buttonStyle(.plain)
    }
}
