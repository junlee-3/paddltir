import SwiftUI

/// Glass segmented capsule for switching between heats. The selected segment shows an
/// accent pill; a trailing `+` affords adding another heat. `selection` is the index into
/// `names`; out-of-range selections are drawn unselected.
public struct HeatSwitcher: View {
    let names: [String]
    @Binding var selection: Int
    var onAdd: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    public init(names: [String], selection: Binding<Int>, onAdd: @escaping () -> Void = {}) {
        self.names = names
        self._selection = selection
        self.onAdd = onAdd
    }

    public var body: some View {
        GlassBar(radius: 999) {
            HStack(spacing: 2) {
                ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                    segment(name: name, selected: index == selection) {
                        if reduceMotion {
                            selection = index
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = index }
                        }
                    }
                    .accessibilityAddTraits(index == selection ? .isSelected : [])
                }

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.dsCaption.weight(.bold))
                        .foregroundStyle(DS.ink2)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add heat")
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func segment(name: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.dsCaption.weight(.bold))
                .foregroundStyle(selected ? DS.onPrimary : DS.ink2)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background {
                    if selected {
                        Capsule().fill(DS.accent).matchedGeometryEffect(id: "heatSelection", in: namespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }
}
