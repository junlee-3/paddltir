import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct LocalStoreTests {
    private func samplePaddler(id: String, clubId: String, name: String) -> PaddlerRow {
        PaddlerRow(
            id: id,
            clubId: clubId,
            profileId: nil,
            name: name,
            email: nil,
            weightKg: 60.0,
            preferredSide: .left,
            gender: .female,
            seatPreference: .stroke,
            boatRole: .paddler,
            archivedAt: nil,
            createdAt: Date(),
            updatedAt: nil
        )
    }

    @Test func migratorCreatesAllTables() throws {
        let appDB = try AppDatabase.inMemory()
        let tableNames = try appDB.read { db in
            try Set(String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'grdb_%'
                """))
        }
        let expected: Set<String> = [
            "clubs", "profiles", "paddlers", "erg_tests", "crews", "crew_members",
            "sessions", "availability", "races", "heats", "seats", "heat_reserves",
            "category_rules", "sync_meta", "outbox",
        ]
        #expect(expected.isSubset(of: tableNames))
    }

    @Test func insertsQueriesSortsAndUpdatesPaddlers() throws {
        let appDB = try AppDatabase.inMemory()
        let clubId = "22222222-2222-2222-2222-222222222222"
        let paddlers = [
            samplePaddler(id: "p-3", clubId: clubId, name: "Charlie"),
            samplePaddler(id: "p-1", clubId: clubId, name: "Alice"),
            samplePaddler(id: "p-2", clubId: clubId, name: "Bob"),
        ]
        try appDB.write { db in
            for paddler in paddlers {
                try paddler.insert(db)
            }
        }

        let sorted = try appDB.read { db in
            try PaddlerRow.order(Column("name")).fetchAll(db)
        }
        #expect(sorted.map(\.name) == ["Alice", "Bob", "Charlie"])

        var updated = sorted[0]
        updated.name = "Alicia"
        updated.weightKg = 61.5
        try appDB.write { db in
            try updated.update(db)
        }

        let refetched = try appDB.read { db in
            try PaddlerRow.fetchOne(db, key: "p-1")
        }
        #expect(refetched?.name == "Alicia")
        #expect(refetched?.weightKg == 61.5)
        // Untouched rows are unaffected by the update.
        #expect(try appDB.read { db in try PaddlerRow.fetchOne(db, key: "p-2") }?.name == "Bob")

        let count = try appDB.read { db in try PaddlerRow.fetchCount(db) }
        #expect(count == 3)
    }

    @Test func outboxRoundTrips() throws {
        let appDB = try AppDatabase.inMemory()
        let entry = OutboxEntry(
            id: "outbox-1",
            tableName: "paddlers",
            pk: "p-1",
            op: "update",
            payload: Data(#"{"name":"Alicia"}"#.utf8),
            createdAt: PostgREST.formatDate(Date())
        )
        try appDB.write { db in try entry.insert(db) }

        let fetched = try appDB.read { db in try OutboxEntry.fetchOne(db, key: "outbox-1") }
        #expect(fetched?.tableName == "paddlers")
        #expect(fetched?.pk == "p-1")
        #expect(fetched?.op == "update")
        #expect(fetched?.payload == entry.payload)

        let count = try appDB.read { db in try OutboxEntry.fetchCount(db) }
        #expect(count == 1)
    }

    @Test func syncMetaReadsAndWrites() throws {
        let appDB = try AppDatabase.inMemory()
        try appDB.write { db in
            try SyncMeta(tableName: "paddlers", lastSync: nil).insert(db)
        }

        var meta = try appDB.read { db in try SyncMeta.fetchOne(db, key: "paddlers") }
        #expect(meta?.lastSync == nil)

        let syncedAt = PostgREST.formatDate(Date())
        try appDB.write { db in
            var current = try SyncMeta.fetchOne(db, key: "paddlers")!
            current.lastSync = syncedAt
            try current.update(db)
        }

        meta = try appDB.read { db in try SyncMeta.fetchOne(db, key: "paddlers") }
        #expect(meta?.lastSync == syncedAt)
    }

    @Test func compositePrimaryKeySeatsRoundTrip() throws {
        let appDB = try AppDatabase.inMemory()
        let seat = SeatRow(
            heatId: "heat-1",
            bench: 2,
            side: .right,
            paddlerId: "p-1",
            locked: true,
            updatedAt: Date()
        )
        try appDB.write { db in try seat.insert(db) }

        let fetchKey: [String: (any DatabaseValueConvertible)?] = [
            "heat_id": "heat-1", "bench": 2, "side": "right",
        ]
        let fetched = try appDB.read { db in try SeatRow.fetchOne(db, key: fetchKey) }
        #expect(fetched?.paddlerId == "p-1")
        #expect(fetched?.locked == true)

        var updatedSeat = try #require(fetched)
        updatedSeat.paddlerId = "p-2"
        try appDB.write { db in try updatedSeat.update(db) }

        let refetched = try appDB.read { db in try SeatRow.fetchOne(db, key: fetchKey) }
        #expect(refetched?.paddlerId == "p-2")

        // A second seat on the same heat but a different (bench, side) is a
        // distinct row under the composite key.
        let otherSeat = SeatRow(
            heatId: "heat-1",
            bench: 2,
            side: .left,
            paddlerId: "p-3",
            locked: false,
            updatedAt: nil
        )
        try appDB.write { db in try otherSeat.insert(db) }

        let count = try appDB.read { db in try SeatRow.fetchCount(db) }
        #expect(count == 2)
    }
}
