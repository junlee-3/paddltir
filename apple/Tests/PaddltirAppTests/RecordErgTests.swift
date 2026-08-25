// apple/Tests/PaddltirAppTests/RecordErgTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct RecordErgTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func recordErgWritesRowAndOutbox() async throws {
        let appDB = try AppDatabase.inMemory()
        let repo = SquadRepository(db: appDB)
        let erg = try await repo.recordErg(paddlerId: "p-1", metres: 620, testedAt: t0, recordedBy: nil)

        #expect(erg.metres == 620)
        #expect(erg.source == .coach)
        let stored = try appDB.read { db in try ErgTest.fetchOne(db, key: erg.id) }
        #expect(stored?.metres == 620)
        let entries = try appDB.read { db in try OutboxEntry.filter(Column("table_name") == "erg_tests").fetchAll(db) }
        #expect(entries.count == 1)
        #expect(entries.first?.op == "insert")
        #expect(entries.first?.pk == erg.id)
    }
}
