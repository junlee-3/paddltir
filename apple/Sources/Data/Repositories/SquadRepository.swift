// SquadRepository.swift
// Async, GRDB-backed, offline-first repository over the `paddlers` (+
// `erg_tests`) local tables — what the Squad feature screens (roster list,
// paddler detail/edit) consume.
//
// Reads go straight to GRDB (`AppDatabase.read`), never the network — the
// local cache is the single source of truth for the UI, kept current by
// `SyncEngine` in the background. Writes commit to GRDB and enqueue an
// `Outbox` entry in the *same* transaction (`AppDatabase.write`), so a write
// and its sync record either both land or neither does; `SyncEngine.syncAll()`
// drains the outbox on its own schedule.

import Foundation
import GRDB

struct SquadRepository: Sendable {
    let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
    }

    /// Non-archived paddlers, alphabetical by name, each joined to their
    /// latest erg test — the local `paddlers_with_power` equivalent.
    func paddlers() async throws -> [PaddlerWithErg] {
        try db.read { db in
            let rows = try PaddlerRow
                .filter(Column("archived_at") == nil)
                .order(Column("name"))
                .fetchAll(db)
            let ergs = try ErgTest
                .filter(rows.map(\.id).contains(Column("paddler_id")))
                .fetchAll(db)
            return PaddlerWithErg.join(rows: rows, ergs: ergs)
        }
    }

    /// A single paddler (archived or not) joined to their latest erg test,
    /// or `nil` if `id` doesn't exist.
    func paddler(id: String) async throws -> PaddlerWithErg? {
        try db.read { db in
            guard let row = try PaddlerRow.fetchOne(db, key: id) else { return nil }
            let ergs = try ErgTest.filter(Column("paddler_id") == id).fetchAll(db)
            return PaddlerWithErg.join(rows: [row], ergs: ergs).first
        }
    }

    /// Inserts `row` if its id is new, otherwise overwrites the existing row
    /// (an "upsert" keyed on the primary key), then enqueues the change for
    /// the next `SyncEngine.syncAll()` push.
    func upsert(_ row: PaddlerRow) async throws {
        try db.write { db in
            let existed = try PaddlerRow.exists(db, key: row.id)
            try row.upsert(db)
            try Outbox.enqueue(
                db: db,
                table: PaddlerRow.databaseTableName,
                pk: row.syncPrimaryKey,
                op: existed ? "update" : "insert",
                payload: try PostgREST.encoder.encode(row)
            )
        }
    }

    /// Soft-deletes a paddler by stamping `archivedAt` (never a hard
    /// delete — matches the server's `paddlers.archived_at` column), then
    /// enqueues the change. No-ops if `id` doesn't exist.
    func archive(id: String) async throws {
        try db.write { db in
            guard var row = try PaddlerRow.fetchOne(db, key: id) else { return }
            row.archivedAt = Date()
            try row.update(db)
            try Outbox.enqueue(
                db: db,
                table: PaddlerRow.databaseTableName,
                pk: row.syncPrimaryKey,
                op: "update",
                payload: try PostgREST.encoder.encode(row)
            )
        }
    }

    /// Records a coach-entered 2-minute erg result (`metres`) for a paddler.
    func recordErg(paddlerId: String, metres: Int, testedAt: Date, recordedBy: String?) async throws -> ErgTest {
        let row = ErgTest(id: UUID().uuidString, paddlerId: paddlerId, testedAt: testedAt,
                          metres: metres, source: .coach, recordedBy: recordedBy, createdAt: Date())
        try db.write { db in
            try row.insert(db)
            try Outbox.enqueue(db: db, table: ErgTest.databaseTableName, pk: row.syncPrimaryKey,
                               op: "insert", payload: try PostgREST.encoder.encode(row))
        }
        return row
    }
}
