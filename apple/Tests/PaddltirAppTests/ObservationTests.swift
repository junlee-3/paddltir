import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct ObservationTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func paddler(_ id: String, _ name: String) -> PaddlerRow {
        PaddlerRow(id: id, clubId: "c1", profileId: nil, name: name, email: nil, weightKg: 70,
                   preferredSide: .left, gender: .female, seatPreference: .none, boatRole: .paddler,
                   archivedAt: nil, createdAt: t0, updatedAt: nil)
    }

    @Test func observePaddlersEmitsInitialThenUpdate() async throws {
        let appDB = try AppDatabase.inMemory()
        var iterator = SquadRepository(db: appDB).observePaddlers().values(in: appDB.dbQueue).makeAsyncIterator()
        let first = try await iterator.next()
        #expect(first?.isEmpty == true)                       // initial value: empty squad
        try appDB.write { db in try paddler("p1", "Ava").insert(db) }
        let second = try await iterator.next()
        #expect(second?.map(\.row.name) == ["Ava"])            // change delivered without any reload call
    }

    @Test func observeScheduleSnapshotTracksSessionsAndSquad() async throws {
        let appDB = try AppDatabase.inMemory()
        var iterator = ScheduleRepository(db: appDB).observeSchedule().values(in: appDB.dbQueue).makeAsyncIterator()
        _ = try await iterator.next()
        try appDB.write { db in
            try paddler("p1", "Ava").insert(db)
            try SessionRow(id: "s1", clubId: "c1", kind: .training, title: "T", startsAt: t0, venue: nil, notes: nil, createdAt: t0, updatedAt: nil).insert(db)
            try Availability(sessionId: "s1", paddlerId: "p1", status: .in, note: nil, updatedAt: t0).insert(db)
        }
        let snap = try await iterator.next()
        #expect(snap?.sessions.map(\.id) == ["s1"])
        #expect(snap?.squadSize == 1)
        #expect(snap?.availabilityBySession["s1"]?.count == 1)
    }

    @Test func loadableValueAccessor() {
        #expect(Loadable<Int>.loading.value == nil)
        #expect(Loadable<Int>.loaded(3).value == 3)
        #expect(Loadable<Int>.failed("x").value == nil)
    }

    @Test func fetchCrewDetailAssemblesCrewMembersRacesSquadAndRule() throws {
        let appDB = try AppDatabase.inMemory()
        try appDB.write { db in
            try Club(id: "c1", name: "Club", inviteCode: "ABC123", createdBy: nil, createdAt: t0, updatedAt: nil).insert(db)
            try Crew(id: "cr1", clubId: "c1", name: "Crew A", ageDivision: "Premier", category: .mixed, createdAt: t0, updatedAt: nil).insert(db)
            try CategoryRule(clubId: "c1", category: .mixed, boatSize: .standard, minWomen: 8, maxWomen: 12, minMen: 8, maxMen: 12, updatedAt: nil).insert(db)
            try paddler("p1", "Ava").insert(db)
            try paddler("p2", "Bo").insert(db)
            try CrewMember(crewId: "cr1", paddlerId: "p1", createdAt: t0).insert(db)
            try CrewMember(crewId: "cr1", paddlerId: "p2", createdAt: t0).insert(db)
            try Race(id: "r1", sessionId: "s1", crewId: "cr1", name: "Heat A", boatSize: .standard, distanceM: 500, sortOrder: 0, createdAt: t0, updatedAt: nil).insert(db)
        }

        let detail = try appDB.read { try CrewRepository.fetchCrewDetail($0, id: "cr1") }
        #expect(detail.crew?.id == "cr1")
        #expect(detail.members.count == 2)
        #expect(detail.races.count == 1)
        #expect(detail.squad.count == 2)
        #expect(detail.rule != nil)

        let missing = try appDB.read { try CrewRepository.fetchCrewDetail($0, id: "does-not-exist") }
        #expect(missing.crew == nil)
        #expect(missing.members.isEmpty)
        #expect(missing.races.isEmpty)
        #expect(missing.rule == nil)
    }
}
