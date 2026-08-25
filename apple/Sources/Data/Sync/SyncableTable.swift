// SyncableTable.swift
// Per-table bridge between PostgREST wire JSON and the local GRDB cache.
//
// SyncEngine is deliberately table-agnostic at its call sites (RemoteStore
// hands back rows as raw `Data`), but applying a pulled row to GRDB must go
// through that table's typed row model — never the raw JSON bytes.
// PostgREST encodes `Date` as ISO 8601 wire strings decoded by
// `PostgREST.decoder` (see PostgRESTCoding.swift), while GRDB stores `Date`
// with its own `.deferredToDate` strategy (see AppDatabase.swift's header
// comment). Those two representations are not byte-compatible, so every
// entry below decodes wire JSON -> Swift `Date` via `PostgREST.decoder`
// first, then inserts the resulting *row model* into GRDB, letting GRDB
// re-encode the `Date` itself on the way in. Raw PostgREST JSON never
// touches a GRDB column directly.
//
// `SyncableRow` standardizes two things every table needs for sync
// bookkeeping that aren't naturally part of the wire schema:
//   - `syncTimestamp`: a single non-optional "last changed" instant driving
//     `since`. Tables with a real `updated_at` column fall back to
//     `created_at` when `updated_at` is unset; append-only tables with no
//     `updated_at` column at all (erg_tests, crew_members, heat_reserves)
//     use `created_at` outright, since they're only ever inserted, never
//     updated. A few tables (availability, seats, category_rules) carry
//     only an optional `updated_at` with no `created_at` at all; those fall
//     back to `.distantPast` in the never-set case so they still sort and
//     compare, though in practice the DB always populates it on insert.
//   - `syncPrimaryKey`: a canonical string primary key, matching the
//     encoding `Outbox.enqueue` callers should use for the same row, so
//     SyncEngine's pull-vs-outbox comparison can match them up. Composite
//     keys join their parts with "|".

import Foundation
import GRDB

protocol SyncableRow {
    var syncTimestamp: Date { get }
    var syncPrimaryKey: String { get }
}

extension Club: SyncableRow {
    var syncTimestamp: Date { updatedAt ?? createdAt }
    var syncPrimaryKey: String { id }
}

extension Profile: SyncableRow {
    var syncTimestamp: Date { updatedAt ?? createdAt }
    var syncPrimaryKey: String { id }
}

extension PaddlerRow: SyncableRow {
    var syncTimestamp: Date { updatedAt ?? createdAt }
    var syncPrimaryKey: String { id }
}

extension ErgTest: SyncableRow {
    var syncTimestamp: Date { createdAt }
    var syncPrimaryKey: String { id }
}

extension Crew: SyncableRow {
    var syncTimestamp: Date { updatedAt ?? createdAt }
    var syncPrimaryKey: String { id }
}

extension CrewMember: SyncableRow {
    var syncTimestamp: Date { createdAt }
    var syncPrimaryKey: String { "\(crewId)|\(paddlerId)" }
}

extension SessionRow: SyncableRow {
    var syncTimestamp: Date { updatedAt ?? createdAt }
    var syncPrimaryKey: String { id }
}

extension Availability: SyncableRow {
    var syncTimestamp: Date { updatedAt ?? .distantPast }
    var syncPrimaryKey: String { "\(sessionId)|\(paddlerId)" }
}

extension Race: SyncableRow {
    var syncTimestamp: Date { updatedAt ?? createdAt }
    var syncPrimaryKey: String { id }
}

extension Heat: SyncableRow {
    var syncTimestamp: Date { updatedAt ?? createdAt }
    var syncPrimaryKey: String { id }
}

extension SeatRow: SyncableRow {
    var syncTimestamp: Date { updatedAt ?? .distantPast }
    var syncPrimaryKey: String { "\(heatId)|\(bench)|\(side.rawValue)" }
}

extension HeatReserve: SyncableRow {
    var syncTimestamp: Date { createdAt }
    var syncPrimaryKey: String { "\(heatId)|\(paddlerId)" }
}

extension CategoryRule: SyncableRow {
    var syncTimestamp: Date { updatedAt ?? .distantPast }
    var syncPrimaryKey: String { "\(clubId)|\(category.rawValue)|\(boatSize.rawValue)" }
}

/// The result of decoding one row's wire JSON: its sync bookkeeping fields,
/// plus a closure that writes the *decoded row model* into GRDB.
struct DecodedSyncRow: Sendable {
    let pk: String
    let syncedAt: Date
    let upsert: @Sendable (Database) throws -> Void
}

/// One registry entry per synced table: knows how to decode that table's
/// PostgREST JSON into its row model and hand back enough for `SyncEngine`
/// to drive pull bookkeeping (see file header). A registry keyed by table
/// name (rather than a `switch table` in the engine) keeps `SyncEngine`
/// itself free of any per-table knowledge.
struct SyncableTable: Sendable {
    let tableName: String
    let decode: @Sendable (Data) throws -> DecodedSyncRow
}

extension SyncableTable {
    private static func entry<Row: Codable & PersistableRecord & SyncableRow & Sendable>(
        _ tableName: String,
        _ rowType: Row.Type
    ) -> SyncableTable {
        SyncableTable(tableName: tableName) { json in
            let row = try PostgREST.decoder.decode(Row.self, from: json)
            return DecodedSyncRow(
                pk: row.syncPrimaryKey,
                syncedAt: row.syncTimestamp,
                upsert: { db in try row.insert(db, onConflict: .replace) }
            )
        }
    }

    /// Every table the sync engine mirrors, in the same order as
    /// AppDatabase's migrator (parents before children — not load-bearing
    /// for SQLite here since foreign keys aren't enforced, but keeps the
    /// list easy to eyeball against the schema).
    static let all: [SyncableTable] = [
        entry(Club.databaseTableName, Club.self),
        entry(Profile.databaseTableName, Profile.self),
        entry(PaddlerRow.databaseTableName, PaddlerRow.self),
        entry(ErgTest.databaseTableName, ErgTest.self),
        entry(Crew.databaseTableName, Crew.self),
        entry(CrewMember.databaseTableName, CrewMember.self),
        entry(SessionRow.databaseTableName, SessionRow.self),
        entry(Availability.databaseTableName, Availability.self),
        entry(Race.databaseTableName, Race.self),
        entry(Heat.databaseTableName, Heat.self),
        entry(SeatRow.databaseTableName, SeatRow.self),
        entry(HeatReserve.databaseTableName, HeatReserve.self),
        entry(CategoryRule.databaseTableName, CategoryRule.self),
    ]
}
