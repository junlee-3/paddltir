import Foundation
import PaddltirCore
import Testing
@testable import Paddltir

@Suite struct MappingTests {
    // MARK: - Fixtures

    private func samplePaddlerRow(
        id: String = "p-1",
        weightKg: Double = 65,
        preferredSide: SidePref = .either,
        gender: RowGender = .female,
        seatPreference: SeatPref = .none,
        boatRole: RowBoatRole = .paddler
    ) -> PaddlerRow {
        PaddlerRow(
            id: id,
            clubId: "club-1",
            profileId: nil,
            name: "Test Paddler",
            email: nil,
            weightKg: weightKg,
            preferredSide: preferredSide,
            gender: gender,
            seatPreference: seatPreference,
            boatRole: boatRole,
            archivedAt: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: nil
        )
    }

    private func ergTest(id: String, paddlerId: String, testedAt: Date, createdAt: Date, metres: Int) -> ErgTest {
        ErgTest(id: id, paddlerId: paddlerId, testedAt: testedAt, metres: metres, source: .coach, recordedBy: nil, createdAt: createdAt)
    }

    // MARK: - paddler(row:latestErg:)

    @Test func paddlerBridgesEnumsByExplicitCase() throws {
        let row = samplePaddlerRow(preferredSide: .right, gender: .male, seatPreference: .sprint, boatRole: .drummer)
        let p = DomainMapping.paddler(row: row, latestErg: nil)
        #expect(p.id == PaddlerID("p-1"))
        #expect(p.side == .right)
        #expect(p.gender == .male)
        #expect(p.seatPref == .sprint)
        #expect(p.role == .drummer)
        #expect(p.weightKg == 65)
    }

    @Test func paddlerWithNoErgDefaultsErgMToZero() throws {
        let p = DomainMapping.paddler(row: samplePaddlerRow(), latestErg: nil)
        #expect(p.ergM == 0)
    }

    @Test func paddlerUsesGivenErgMetres() throws {
        let erg = ergTest(id: "e-1", paddlerId: "p-1", testedAt: Date(timeIntervalSince1970: 1000), createdAt: Date(timeIntervalSince1970: 1000), metres: 512)
        let p = DomainMapping.paddler(row: samplePaddlerRow(), latestErg: erg)
        #expect(p.ergM == 512)
    }

    // MARK: - roster(rows:ergs:) — latest-erg selection

    @Test func rosterPicksLatestErgByTestedAt() throws {
        let row = samplePaddlerRow(id: "p-1")
        let older = ergTest(id: "e-1", paddlerId: "p-1", testedAt: Date(timeIntervalSince1970: 1000), createdAt: Date(timeIntervalSince1970: 1000), metres: 400)
        let newer = ergTest(id: "e-2", paddlerId: "p-1", testedAt: Date(timeIntervalSince1970: 2000), createdAt: Date(timeIntervalSince1970: 1500), metres: 500)
        let roster = DomainMapping.roster(rows: [row], ergs: [older, newer])
        #expect(roster[PaddlerID("p-1")]?.ergM == 500)
    }

    @Test func rosterTiebreaksEqualTestedAtByCreatedAt() throws {
        let row = samplePaddlerRow(id: "p-1")
        let sameTestDay = Date(timeIntervalSince1970: 1000)
        let earlyCreated = ergTest(id: "e-1", paddlerId: "p-1", testedAt: sameTestDay, createdAt: Date(timeIntervalSince1970: 1000), metres: 400)
        let lateCreated = ergTest(id: "e-2", paddlerId: "p-1", testedAt: sameTestDay, createdAt: Date(timeIntervalSince1970: 2000), metres: 450)
        // Order shouldn't matter — feed the later-created one first too.
        let rosterA = DomainMapping.roster(rows: [row], ergs: [earlyCreated, lateCreated])
        let rosterB = DomainMapping.roster(rows: [row], ergs: [lateCreated, earlyCreated])
        #expect(rosterA[PaddlerID("p-1")]?.ergM == 450)
        #expect(rosterB[PaddlerID("p-1")]?.ergM == 450)
    }

    @Test func rosterIgnoresErgsForOtherPaddlers() throws {
        let rows = [samplePaddlerRow(id: "p-1"), samplePaddlerRow(id: "p-2")]
        let ergs = [ergTest(id: "e-1", paddlerId: "p-2", testedAt: Date(), createdAt: Date(), metres: 600)]
        let roster = DomainMapping.roster(rows: rows, ergs: ergs)
        #expect(roster[PaddlerID("p-1")]?.ergM == 0)
        #expect(roster[PaddlerID("p-2")]?.ergM == 600)
        #expect(roster.count == 2)
    }

    // MARK: - genderRule(_:)

    @Test func genderRuleMapsAllFields() throws {
        let rule = CategoryRule(clubId: "club-1", category: .mixed, boatSize: .standard, minWomen: 8, maxWomen: 12, minMen: 8, maxMen: 12, updatedAt: nil)
        let mapped = DomainMapping.genderRule(rule)
        #expect(mapped == GenderRule(minWomen: 8, maxWomen: 12, minMen: 8, maxMen: 12))
    }

    @Test func genderRulePassesThroughPartialNils() throws {
        let rule = CategoryRule(clubId: "club-1", category: .women, boatSize: .small, minWomen: nil, maxWomen: nil, minMen: 0, maxMen: 0, updatedAt: nil)
        let mapped = DomainMapping.genderRule(rule)
        #expect(mapped == GenderRule(minWomen: nil, maxWomen: nil, minMen: 0, maxMen: 0))
    }

    @Test func genderRuleNilInputYieldsNil() throws {
        #expect(DomainMapping.genderRule(nil) == nil)
    }

    // MARK: - boat(size:)

    @Test func boatMapsSizeToBenchCount() throws {
        #expect(DomainMapping.boat(size: .small) == Boat.small)
        #expect(DomainMapping.boat(size: .small).benches == 5)
        #expect(DomainMapping.boat(size: .standard) == Boat.standard)
        #expect(DomainMapping.boat(size: .standard).benches == 10)
    }

    // MARK: - lineup(heat:seats:boat:)

    @Test func lineupMapsSeatsDrummerAndSweep() throws {
        let heat = Heat(
            id: "heat-1", raceId: "race-1", name: "Heat 1", sortOrder: 0,
            drummerId: "p-drummer", sweepId: "p-sweep",
            createdAt: Date(), updatedAt: nil
        )
        let seats = [
            SeatRow(heatId: "heat-1", bench: 1, side: .left, paddlerId: "p-1", locked: true, updatedAt: nil),
            SeatRow(heatId: "heat-1", bench: 1, side: .right, paddlerId: "p-2", locked: false, updatedAt: nil),
            SeatRow(heatId: "heat-1", bench: 2, side: .left, paddlerId: "p-3", locked: false, updatedAt: nil),
        ]
        let boat = DomainMapping.boat(size: .small)
        let lineup = DomainMapping.lineup(heat: heat, seats: seats, boat: boat)

        #expect(lineup.drummerId == PaddlerID("p-drummer"))
        #expect(lineup.sweepId == PaddlerID("p-sweep"))
        #expect(lineup.paddler(at: Seat(bench: 1, side: .left)) == PaddlerID("p-1"))
        #expect(lineup.paddler(at: Seat(bench: 1, side: .right)) == PaddlerID("p-2"))
        #expect(lineup.paddler(at: Seat(bench: 2, side: .left)) == PaddlerID("p-3"))
        #expect(lineup.isLocked(Seat(bench: 1, side: .left)) == true)
        #expect(lineup.isLocked(Seat(bench: 1, side: .right)) == false)
        #expect(lineup.assignments.count == 3)
    }

    @Test func lineupWithNoDrummerOrSweepMapsToNil() throws {
        let heat = Heat(
            id: "heat-2", raceId: "race-1", name: "Heat 2", sortOrder: 1,
            drummerId: nil, sweepId: nil,
            createdAt: Date(), updatedAt: nil
        )
        let lineup = DomainMapping.lineup(heat: heat, seats: [], boat: DomainMapping.boat(size: .standard))
        #expect(lineup.drummerId == nil)
        #expect(lineup.sweepId == nil)
        #expect(lineup.assignments.isEmpty)
    }

    // MARK: - Integration sanity: mapped roster + rule feed Greedy.autoFill

    @Test func mappedRosterAndRuleProduceFullValidLineupViaGreedy() throws {
        // 10 paddlers (5 women, 5 men) mapped from DB rows, targeting a
        // small boat (5 benches, 10 seats) so candidates exactly fill it.
        var rows: [PaddlerRow] = []
        var ergs: [ErgTest] = []
        for i in 0..<10 {
            let id = "p-\(i)"
            let gender: RowGender = i < 5 ? .female : .male
            rows.append(samplePaddlerRow(id: id, weightKg: 55 + Double(i), preferredSide: .either, gender: gender, seatPreference: .none, boatRole: .paddler))
            ergs.append(ergTest(id: "erg-\(id)", paddlerId: id, testedAt: Date(timeIntervalSince1970: 1000), createdAt: Date(timeIntervalSince1970: 1000), metres: 400 + i * 5))
        }
        let categoryRule = CategoryRule(clubId: "club-1", category: .mixed, boatSize: .small, minWomen: 4, maxWomen: 6, minMen: 4, maxMen: 6, updatedAt: nil)

        let roster = DomainMapping.roster(rows: rows, ergs: ergs)
        let rule = DomainMapping.genderRule(categoryRule)
        let boat = DomainMapping.boat(size: .small)

        #expect(roster.count == 10)

        let request = PlacementRequest(boat: boat, roster: roster, candidates: roster.ids, rule: rule)
        let result = Greedy.autoFill(request)

        #expect(result.lineup.isFull)
        #expect(result.lineup.assignments.count == boat.capacity)
        #expect(result.ruleSatisfied)
        #expect(result.unseated.isEmpty)
        // Every seated paddler ID round-trips through the mapping (came from a real row id).
        for id in result.lineup.seatedIDs {
            #expect(roster[id] != nil)
        }
    }
}
