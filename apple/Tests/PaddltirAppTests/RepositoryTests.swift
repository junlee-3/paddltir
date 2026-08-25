// RepositoryTests.swift
// Exercises the four repositories (Repositories/{Squad,Crew,Schedule,Lineup}Repository.swift)
// against an in-memory AppDatabase seeded with demo-shaped rows: one club, a
// 10-paddler crew (5 women, 5 men, each with an erg test), a session with a
// race and a heat, and a category rule for the race's category+boat size.
// Covers every repository read, a write's GRDB-row-plus-outbox-entry shape,
// and — the trickiest assembly in this task —
// LineupRepository.placementRequest(heatId:), sanity-checked by feeding its
// result straight into Greedy.autoFill.

import Foundation
import GRDB
import PaddltirCore
import Testing
@testable import Paddltir

@Suite struct RepositoryTests {
    // MARK: - Fixtures

    private let clubId = "22222222-2222-2222-2222-222222222222"

    private func paddlerRow(
        id: String,
        name: String,
        gender: RowGender = .female,
        weightKg: Double = 60,
        boatRole: RowBoatRole = .paddler,
        archivedAt: Date? = nil
    ) -> PaddlerRow {
        PaddlerRow(
            id: id,
            clubId: clubId,
            profileId: nil,
            name: name,
            email: nil,
            weightKg: weightKg,
            preferredSide: .either,
            gender: gender,
            seatPreference: .none,
            boatRole: boatRole,
            archivedAt: archivedAt,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: nil
        )
    }

    private func ergTest(id: String, paddlerId: String, testedAt: Date, metres: Int) -> ErgTest {
        ErgTest(id: id, paddlerId: paddlerId, testedAt: testedAt, metres: metres, source: .coach, recordedBy: nil, createdAt: testedAt)
    }

    /// Seeds one club's worth of demo-shaped rows: a crew of 10 paddlers
    /// (p-0...p-4 women, p-5...p-9 men, named so alphabetical name order is
    /// "Paddler 0" ... "Paddler 9" i.e. the *reverse* of paddler-id order —
    /// so a sort-by-name test can't pass by accident of insertion order),
    /// each with one erg test (p-0 gets two, to exercise "latest wins"), an
    /// archived paddler excluded from SquadRepository.paddlers(), one crew
    /// containing all ten, a session with a race (small boat) and a heat,
    /// and a category rule for that race's category+boat size.
    @discardableResult
    private func seedDemo(_ appDB: AppDatabase) throws -> (crewId: String, sessionId: String, raceId: String, heatId: String) {
        let crewId = "crew-1"
        let sessionId = "session-1"
        let raceId = "race-1"
        let heatId = "heat-1"

        try appDB.write { db in
            try Crew(id: crewId, clubId: clubId, name: "Crew 1", ageDivision: "Premier", category: .mixed, createdAt: Date(), updatedAt: nil)
                .insert(db)

            for i in 0..<10 {
                let pid = "p-\(i)"
                let gender: RowGender = i < 5 ? .female : .male
                try paddlerRow(id: pid, name: "Paddler \(9 - i)", gender: gender, weightKg: 55 + Double(i)).insert(db)
                try ergTest(id: "erg-\(pid)", paddlerId: pid, testedAt: Date(timeIntervalSince1970: 1000), metres: 400 + i * 5).insert(db)
                try CrewMember(crewId: crewId, paddlerId: pid, createdAt: Date()).insert(db)
            }
            // An older erg test for p-0, so "latest by testedAt" is genuinely exercised.
            try ergTest(id: "erg-p-0-old", paddlerId: "p-0", testedAt: Date(timeIntervalSince1970: 500), metres: 100).insert(db)

            // Archived — must not appear in SquadRepository.paddlers().
            try paddlerRow(id: "p-archived", name: "Archived Annie", archivedAt: Date()).insert(db)

            try SessionRow(id: sessionId, clubId: clubId, kind: .training, title: "Tuesday", startsAt: Date(timeIntervalSince1970: 2000), venue: nil, notes: nil, createdAt: Date(), updatedAt: nil)
                .insert(db)
            try Race(id: raceId, sessionId: sessionId, crewId: crewId, name: "Race 1", boatSize: .small, distanceM: nil, sortOrder: 0, createdAt: Date(), updatedAt: nil)
                .insert(db)
            try Heat(id: heatId, raceId: raceId, name: "Heat 1", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil)
                .insert(db)

            try CategoryRule(clubId: clubId, category: .mixed, boatSize: .small, minWomen: 4, maxWomen: 6, minMen: 4, maxMen: 6, updatedAt: nil)
                .insert(db)
        }
        return (crewId, sessionId, raceId, heatId)
    }

    // MARK: - SquadRepository

    @Test func paddlersReturnsNonArchivedSortedWithLatestErg() async throws {
        let appDB = try AppDatabase.inMemory()
        try seedDemo(appDB)
        let repo = SquadRepository(db: appDB)

        let paddlers = try await repo.paddlers()

        #expect(paddlers.map(\.row.name) == (0..<10).map { "Paddler \($0)" })
        #expect(!paddlers.contains { $0.row.id == "p-archived" })

        let p0 = try #require(paddlers.first { $0.row.id == "p-0" })
        #expect(p0.latestErg?.metres == 400) // the newer of p-0's two erg tests, not the older 100m one
        #expect(p0.paddler.ergM == 400)
    }

    @Test func paddlerByIdReturnsJoinedRowOrNil() async throws {
        let appDB = try AppDatabase.inMemory()
        try seedDemo(appDB)
        let repo = SquadRepository(db: appDB)

        let found = try await repo.paddler(id: "p-1")
        #expect(found?.row.id == "p-1")
        #expect(found?.latestErg?.metres == 405)

        let missing = try await repo.paddler(id: "does-not-exist")
        #expect(missing == nil)
    }

    @Test func upsertWritesRowAndEnqueuesOutboxEntry() async throws {
        let appDB = try AppDatabase.inMemory()
        try seedDemo(appDB)
        let repo = SquadRepository(db: appDB)

        var updated = try #require(try appDB.read { db in try PaddlerRow.fetchOne(db, key: "p-1") })
        updated.name = "Renamed"
        updated.weightKg = 70
        try await repo.upsert(updated)

        let refetched = try appDB.read { db in try PaddlerRow.fetchOne(db, key: "p-1") }
        #expect(refetched?.name == "Renamed")
        #expect(refetched?.weightKg == 70)

        let updateOutbox = try appDB.read { db in
            try OutboxEntry.filter(Column("table_name") == "paddlers" && Column("pk") == "p-1").fetchAll(db)
        }
        #expect(updateOutbox.count == 1)
        #expect(updateOutbox.first?.op == "update")

        // A brand-new id is enqueued as an insert, not an update.
        try await repo.upsert(paddlerRow(id: "p-new", name: "New Paddler"))
        let insertOutbox = try appDB.read { db in
            try OutboxEntry.filter(Column("table_name") == "paddlers" && Column("pk") == "p-new").fetchAll(db)
        }
        #expect(insertOutbox.first?.op == "insert")
        #expect(try appDB.read { db in try PaddlerRow.fetchOne(db, key: "p-new") } != nil)
    }

    @Test func archiveSetsArchivedAtAndEnqueuesOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        try seedDemo(appDB)
        let repo = SquadRepository(db: appDB)

        try await repo.archive(id: "p-2")

        let row = try appDB.read { db in try PaddlerRow.fetchOne(db, key: "p-2") }
        #expect(row?.archivedAt != nil)

        let stillListed = try await repo.paddlers()
        #expect(!stillListed.contains { $0.row.id == "p-2" })

        let outbox = try appDB.read { db in
            try OutboxEntry.filter(Column("table_name") == "paddlers" && Column("pk") == "p-2").fetchAll(db)
        }
        #expect(outbox.count == 1)
        #expect(outbox.first?.op == "update")
    }

    // MARK: - CrewRepository

    @Test func crewsReturnsAllCrewsSortedByName() async throws {
        let appDB = try AppDatabase.inMemory()
        let (crewId, _, _, _) = try seedDemo(appDB)
        try appDB.write { db in
            try Crew(id: "crew-0", clubId: clubId, name: "Ahead Alphabetically", ageDivision: "18U", category: .open, createdAt: Date(), updatedAt: nil).insert(db)
        }
        let repo = CrewRepository(db: appDB)

        let crews = try await repo.crews()
        #expect(crews.map(\.id) == ["crew-0", crewId])
    }

    @Test func crewByIdReturnsMembersJoinedToLatestErg() async throws {
        let appDB = try AppDatabase.inMemory()
        let (crewId, _, _, _) = try seedDemo(appDB)
        let repo = CrewRepository(db: appDB)

        let found = try await repo.crew(id: crewId)
        let (crew, members) = try #require(found)
        #expect(crew.id == crewId)
        #expect(members.count == 10)
        #expect(members.contains { $0.row.id == "p-0" && $0.latestErg?.metres == 400 })

        #expect(try await repo.crew(id: "no-such-crew") == nil)
    }

    @Test func setMembersReplacesMembershipByDiffAndEnqueuesOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        let (crewId, _, _, _) = try seedDemo(appDB)
        let repo = CrewRepository(db: appDB)

        try await repo.setMembers(crewId: crewId, paddlerIds: ["p-0", "p-1", "p-new-member"])

        let members = try appDB.read { db in try CrewMember.filter(Column("crew_id") == crewId).fetchAll(db) }
        #expect(Set(members.map(\.paddlerId)) == ["p-0", "p-1", "p-new-member"])

        let outbox = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "crew_members").fetchAll(db) }
        // 8 removed (p-2...p-9) + 1 added (p-new-member) = 9 entries; p-0/p-1 stayed, so no churn for them.
        #expect(outbox.count == 9)
        #expect(outbox.filter { $0.op == "delete" }.count == 8)
        #expect(outbox.filter { $0.op == "insert" }.count == 1)
    }

    // MARK: - ScheduleRepository

    @Test func upcomingSessionsSortedByStartsAt() async throws {
        let appDB = try AppDatabase.inMemory()
        let (_, sessionId, _, _) = try seedDemo(appDB)
        try appDB.write { db in
            try SessionRow(id: "session-0", clubId: clubId, kind: .training, title: "Earlier", startsAt: Date(timeIntervalSince1970: 1000), venue: nil, notes: nil, createdAt: Date(), updatedAt: nil)
                .insert(db)
        }
        let repo = ScheduleRepository(db: appDB)

        let sessions = try await repo.sessions()
        #expect(sessions.map(\.id) == ["session-0", sessionId])
    }

    @Test func sessionByIdReturnsAvailabilityOrNil() async throws {
        let appDB = try AppDatabase.inMemory()
        let (_, sessionId, _, _) = try seedDemo(appDB)
        try appDB.write { db in
            try Availability(sessionId: sessionId, paddlerId: "p-0", status: .in, note: nil, updatedAt: Date()).insert(db)
            try Availability(sessionId: sessionId, paddlerId: "p-1", status: .out, note: "injured", updatedAt: Date()).insert(db)
        }
        let repo = ScheduleRepository(db: appDB)

        let found = try await repo.session(id: sessionId)
        let (session, availability) = try #require(found)
        #expect(session.id == sessionId)
        #expect(availability.count == 2)
        #expect(availability.first { $0.paddlerId == "p-1" }?.status == .out)

        #expect(try await repo.session(id: "no-such-session") == nil)
    }

    @Test func racesForSessionSortedBySortOrder() async throws {
        let appDB = try AppDatabase.inMemory()
        let (crewId, sessionId, raceId, _) = try seedDemo(appDB)
        try appDB.write { db in
            try Race(id: "race-0", sessionId: sessionId, crewId: crewId, name: "Earlier Race", boatSize: .standard, distanceM: nil, sortOrder: -1, createdAt: Date(), updatedAt: nil)
                .insert(db)
        }
        let repo = ScheduleRepository(db: appDB)

        let races = try await repo.races(sessionId: sessionId)
        #expect(races.map(\.id) == ["race-0", raceId])
    }

    // MARK: - LineupRepository

    @Test func heatByIdReturnsSeatsAndReservesOrNil() async throws {
        let appDB = try AppDatabase.inMemory()
        let (_, _, _, heatId) = try seedDemo(appDB)
        try appDB.write { db in
            try SeatRow(heatId: heatId, bench: 1, side: .left, paddlerId: "p-0", locked: true, updatedAt: nil).insert(db)
            try HeatReserve(heatId: heatId, paddlerId: "p-9", createdAt: Date()).insert(db)
        }
        let repo = LineupRepository(db: appDB)

        let found = try await repo.heat(id: heatId)
        let (heat, seats, reserves) = try #require(found)
        #expect(heat.id == heatId)
        #expect(seats.count == 1)
        #expect(reserves.map(\.paddlerId) == ["p-9"])

        #expect(try await repo.heat(id: "no-such-heat") == nil)
    }

    @Test func saveSeatsReplacesByDiffAndEnqueuesOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        let (_, _, _, heatId) = try seedDemo(appDB)
        try appDB.write { db in
            // A pre-existing seat that the new set drops (bench 1 left).
            try SeatRow(heatId: heatId, bench: 1, side: .left, paddlerId: "p-0", locked: false, updatedAt: nil).insert(db)
        }
        let repo = LineupRepository(db: appDB)

        let newSeats = [
            SeatRow(heatId: heatId, bench: 1, side: .right, paddlerId: "p-1", locked: false, updatedAt: nil),
            SeatRow(heatId: heatId, bench: 2, side: .left, paddlerId: "p-2", locked: true, updatedAt: nil),
        ]
        try await repo.saveSeats(heatId: heatId, seats: newSeats)

        let stored = try appDB.read { db in try SeatRow.filter(Column("heat_id") == heatId).fetchAll(db) }
        #expect(Set(stored.map(\.paddlerId)) == ["p-1", "p-2"])
        #expect(stored.first { $0.paddlerId == "p-2" }?.locked == true)

        let outbox = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "seats").fetchAll(db) }
        #expect(outbox.filter { $0.op == "delete" }.count == 1) // the dropped bench-1-left seat
        #expect(outbox.filter { $0.op == "update" }.count == 2) // both new seats
    }

    @Test func placementRequestAssemblesRosterRuleSeatsAndFeedsGreedyToAFullLineup() async throws {
        let appDB = try AppDatabase.inMemory()
        let (_, _, _, heatId) = try seedDemo(appDB)
        try appDB.write { db in
            // Lock one seat so PlacementRequest.locked/current are non-empty.
            try SeatRow(heatId: heatId, bench: 1, side: .left, paddlerId: "p-0", locked: true, updatedAt: nil).insert(db)
        }
        let repo = LineupRepository(db: appDB)

        let request = try await repo.placementRequest(heatId: heatId)
        let req = try #require(request)

        #expect(req.boat == Boat.small) // race.boatSize == .small
        #expect(req.roster.count == 10) // the crew's 10 members, not the archived paddler
        #expect(req.candidates.count == 10)
        #expect(req.rule == GenderRule(minWomen: 4, maxWomen: 6, minMen: 4, maxMen: 6))
        #expect(req.drummerId == nil)
        #expect(req.sweepId == nil)
        #expect(req.locked.count == 1)
        #expect(req.locked.first?.paddlerId == PaddlerID("p-0"))
        #expect(req.current?.assignments.count == 1)

        // Sanity: hand the assembled request straight to Greedy.autoFill, the
        // same call the editor's Auto-fill/Suggest action makes.
        let result = Greedy.autoFill(req)
        #expect(result.lineup.isFull)
        #expect(result.lineup.assignments.count == Boat.small.capacity)
        #expect(result.ruleSatisfied)
        #expect(result.unseated.isEmpty)
        #expect(result.lineup.paddler(at: Seat(bench: 1, side: .left)) == PaddlerID("p-0")) // the locked seat held
    }

    @Test func placementRequestReturnsNilForUnknownHeat() async throws {
        let appDB = try AppDatabase.inMemory()
        try seedDemo(appDB)
        let repo = LineupRepository(db: appDB)

        #expect(try await repo.placementRequest(heatId: "no-such-heat") == nil)
    }
}
