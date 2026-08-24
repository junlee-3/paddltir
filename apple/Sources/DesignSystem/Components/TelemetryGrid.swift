import SwiftUI
import PaddltirCore

/// A single label/value row in a `TelemetryGrid`. Exposed so callers can build a warning
/// summary or a legend from the same data without recomputing colours.
public struct TelemetryItem: Identifiable {
    public let label: String
    public let value: String
    public let ok: Bool
    public var id: String { label }
    public init(label: String, value: String, ok: Bool) { self.label = label; self.value = value; self.ok = ok }
}

/// 2-column grid of lineup telemetry — weight/power balance, trim, side preference —
/// coloured `DS.good` when within threshold and `DS.danger` when `metrics.warnings(boat:thresholds:)` flags it.
public struct TelemetryGrid: View {
    let metrics: Metrics
    let boat: Boat
    var thresholds: Thresholds = .default

    public init(metrics: Metrics, boat: Boat, thresholds: Thresholds = .default) {
        self.metrics = metrics; self.boat = boat; self.thresholds = thresholds
    }

    var warnings: Set<Metrics.Warning> { metrics.warnings(boat: boat, thresholds: thresholds) }

    public var body: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible())]
        LazyVGrid(columns: cols, spacing: 7) {
            item("Weight", "\(Int(metrics.weightDelta)) kg", ok: !warnings.contains(.weight))
            item("Power", metrics.totalPower > 0 ? "\(Int((metrics.powerDelta / metrics.totalPower) * 100))%" : "—", ok: !warnings.contains(.power))
            item("Trim", warnings.contains(.trim) ? "\(Int(metrics.trimDeltaKg(boat: boat))) kg" : "level", ok: !warnings.contains(.trim))
            item("Side pref", "\(Int(metrics.sidePreferenceFraction * 100))%", ok: !warnings.contains(.side))
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder func item(_ l: String, _ v: String, ok: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            MicroLabel(l)
            Spacer()
            Text(v).font(.dsCaption.weight(.bold)).monospacedDigit().foregroundStyle(ok ? DS.good : DS.danger)
        }
        .padding(.bottom, 5)
        .overlay(alignment: .bottom) { Rectangle().fill(DS.border2).frame(height: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(l): \(v)\(ok ? "" : ", warning")")
    }
}

/// Compact women/men count badge, coloured with the same gender palette as `SeatTile`.
public struct GenderBadge: View {
    let women: Int
    let men: Int
    public init(women: Int, men: Int) { self.women = women; self.men = men }
    public init(metrics: Metrics) { self.women = metrics.women; self.men = metrics.men }

    public var body: some View {
        HStack(spacing: 6) {
            badge(count: women, fill: DS.femaleFill, stroke: DS.femaleBorder)
            badge(count: men, fill: DS.maleFill, stroke: DS.maleBorder)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(women) women, \(men) men")
    }

    @ViewBuilder func badge(count: Int, fill: Color, stroke: Color) -> some View {
        Text("\(count)")
            .font(.dsCaption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(DS.ink)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(fill, in: .rect(cornerRadius: DS.R.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.R.sm).stroke(stroke, lineWidth: 1))
    }
}
