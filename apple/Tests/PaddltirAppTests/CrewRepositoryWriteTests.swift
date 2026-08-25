import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct CrewRepositoryWriteTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func createCrewWritesRowAndOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = CrewRepository(db: appDB)
        let crew = try await repo.createCrew(clubId: "club-1", name: "A Crew", ageDivision: "Premier", category: .mixed)
        #expect(crew.name == "A Crew")
        #expect(crew.category == .mixed)
        let stored = try appDB.read { db in try Crew.fetchOne(db, key: crew.id) }
        #expect(stored?.ageDivision == "Premier")
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "crews").fetchAll(db) }
        #expect(entries.count == 1)
        #expect(entries.first?.op == "insert")
    }

    @Test func summariesCountMembersAndFindNextRace() async throws {
        let appDB = try AppDatabase.inMemory()
        try appDB.write { db in
            try Crew(id: "c-1", clubId: "club-1", name: "Alpha", ageDivision: "Premier", category: .mixed, createdAt: t0, updatedAt: nil).insert(db)
            try CrewMember(crewId: "c-1", paddlerId: "p-1", createdAt: t0).insert(db)
            try CrewMember(crewId: "c-1", paddlerId: "p-2", createdAt: t0).insert(db)
            // a future session with a race for this crew
            try SessionRow(id: "s-1", clubId: "club-1", kind: .raceDay, title: "Regatta", startsAt: t0.addingTimeInterval(86_400), venue: nil, notes: nil, createdAt: t0, updatedAt: nil).insert(db)
            try Race(id: "r-1", sessionId: "s-1", crewId: "c-1", name: "Heat A", boatSize: .standard, distanceM: 500, sortOrder: 0, createdAt: t0, updatedAt: nil).insert(db)
        }
        let summaries = try await CrewRepository(db: appDB).summaries(now: t0)
        #expect(summaries.count == 1)
        #expect(summaries[0].memberCount == 2)
        #expect(summaries[0].nextRaceName == "Heat A")
    }
}
