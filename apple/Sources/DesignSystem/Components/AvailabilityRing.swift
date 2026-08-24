import SwiftUI

/// Conic-gradient ring showing `count` of `total` available (e.g. paddlers confirmed for a
/// session), with the raw count centred inside. Used on session cards.
public struct AvailabilityRing: View {
    let count: Int
    let total: Int
    var diameter: CGFloat = 44
    var lineWidth: CGFloat = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(count: Int, total: Int, diameter: CGFloat = 44, lineWidth: CGFloat = 4) {
        self.count = count; self.total = total; self.diameter = diameter; self.lineWidth = lineWidth
    }

    private var fraction: Double { total > 0 ? min(1, max(0, Double(count) / Double(total))) : 0 }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(DS.border2, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [DS.good.opacity(0.55), DS.good]),
                        center: .center, startAngle: .degrees(0), endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: fraction)

            Text("\(count)")
                .font(.dsCaption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(DS.ink)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Availability")
        .accessibilityValue("\(count) of \(total) available")
    }
}
