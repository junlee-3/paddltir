import Foundation
import Testing
@testable import Paddltir

@Suite struct SquadModelsTests {
    private func p(_ id: String, _ name: String, weight: Double, side: SidePref, gender: RowGender,
                  role: RowBoatRole = .paddler, linked: Bool = false, erg: Int? = nil) -> PaddlerWithErg {
        let row = PaddlerRow(id: id, clubId: "c", profileId: linked ? "u-\(id)" : nil, name: name, email: nil,
                             weightKg: weight, preferredSide: side, gender: gender, seatPreference: .engine,
                             boatRole: role, archivedAt: nil, createdAt: Date(), updatedAt: nil)
        let e = erg.map { ErgTest(id: "e-\(id)", paddlerId: id, testedAt: Date(), metres: $0, source: .coach, recordedBy: nil, createdAt: Date()) }
        return PaddlerWithErg(row: row, latestErg: e)
    }
    private var squad: [PaddlerWithErg] {
        [
            p("1", "Alice", weight: 62, side: .left, gender: .female, linked: true, erg: 600),
            p("2", "Bob", weight: 80, side: .right, gender: .male, erg: 640),
            p("3", "Cara", weight: 58, side: .left, gender: .female, role: .drummer),
        ]
    }

    @Test func searchMatchesNameCaseInsensitive() {
        let out = SquadQuery.apply(squad, filter: SquadFilter(search: "ali"), sort: .name)
        #expect(out.map(\.row.id) == ["1"])
    }
    @Test func filtersCombine() {
        var f = SquadFilter(); f.side = .left; f.gender = .female
        #expect(SquadQuery.apply(squad, filter: f, sort: .name).map(\.row.id) == ["1", "3"])
        var g = SquadFilter(); g.linkedOnly = true
        #expect(SquadQuery.apply(squad, filter: g, sort: .name).map(\.row.id) == ["1"])
        var r = SquadFilter(); r.role = .drummer
        #expect(SquadQuery.apply(squad, filter: r, sort: .name).map(\.row.id) == ["3"])
    }
    @Test func sortByWeightAscAndErgDescNilLast() {
        #expect(SquadQuery.apply(squad, filter: SquadFilter(), sort: .weight).map(\.row.id) == ["3", "1", "2"])
        // erg desc: 640, 600, then nil last
        #expect(SquadQuery.apply(squad, filter: SquadFilter(), sort: .erg).map(\.row.id) == ["2", "1", "3"])
    }
    @Test func genderTallyCounts() {
        #expect(GenderTally.of(squad) == GenderTally(women: 2, men: 1))
    }
}
