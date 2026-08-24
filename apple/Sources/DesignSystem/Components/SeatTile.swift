import SwiftUI
import PaddltirCore

/// CrewCoach seat tile — gender-coloured fill/border, name + side letter + weight.
/// `violatesPref` overrides the border with `DS.danger`; `lifted` scales up with a drop shadow
/// (used while a tile is being dragged in the CrewCoach board).
public struct SeatTile: View {
    let name: String
    let side: String
    let weightKg: Double
    let gender: Gender
    var violatesPref = false
    var lifted = false

    public init(name: String, side: String, weightKg: Double, gender: Gender, violatesPref: Bool = false, lifted: Bool = false) {
        self.name = name; self.side = side; self.weightKg = weightKg; self.gender = gender
        self.violatesPref = violatesPref; self.lifted = lifted
    }

    var fill: Color { gender == .male ? DS.maleFill : DS.femaleFill }
    var stroke: Color { violatesPref ? DS.danger : (gender == .male ? DS.maleBorder : DS.femaleBorder) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name).font(.dsFootnote.weight(.semibold)).foregroundStyle(DS.ink).lineLimit(1)
            HStack(spacing: 5) {
                Text(side).font(.dsCaption.weight(.bold)).foregroundStyle(violatesPref ? DS.danger : DS.ink)
                Text(weightKg, format: .number.precision(.fractionLength(0))).font(.dsCaption).monospacedDigit().foregroundStyle(DS.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(fill, in: .rect(cornerRadius: DS.R.tile))
        .overlay(RoundedRectangle(cornerRadius: DS.R.tile).stroke(stroke, lineWidth: violatesPref ? 1.5 : 1))
        .scaleEffect(lifted ? 1.05 : 1)
        .shadow(color: .black.opacity(lifted ? 0.28 : 0), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(gender == .male ? "male" : "female"), side \(side), \(Int(weightKg)) kilograms\(violatesPref ? ", side preference not met" : "")")
    }
}
