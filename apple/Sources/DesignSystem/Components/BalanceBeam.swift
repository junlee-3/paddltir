import SwiftUI

/// Slim hairline track with an accent indicator offset by a normalised imbalance.
/// `imbalance` is clamped to −1…+1: 0 is centred (balanced), negative pulls the
/// indicator left, positive pulls it right. Used for weight/power left-right balance.
public struct BalanceBeam: View {
    let imbalance: Double
    var label: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(imbalance: Double, label: String? = nil) {
        self.imbalance = imbalance
        self.label = label
    }

    private var clamped: Double { min(1, max(-1, imbalance)) }

    public var body: some View {
        GeometryReader { geo in
            let trackHeight: CGFloat = 3
            let knobSize: CGFloat = 12
            let usableWidth = geo.size.width - knobSize
            let x = knobSize / 2 + usableWidth * CGFloat((clamped + 1) / 2)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DS.border2)
                    .frame(height: trackHeight)
                    .frame(maxHeight: .infinity, alignment: .center)

                Rectangle()
                    .fill(DS.border)
                    .frame(width: 1, height: 8)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                Circle()
                    .fill(DS.accent)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .position(x: x, y: geo.size.height / 2)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: clamped)
            }
        }
        .frame(height: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Balance")
        .accessibilityValue(clamped == 0 ? "centred" : (clamped < 0 ? "left, \(Int(abs(clamped) * 100)) percent" : "right, \(Int(clamped * 100)) percent"))
    }
}
