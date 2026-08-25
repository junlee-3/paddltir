// AppDatabase.swift
// GRDB-backed local store: schema migrations and a DatabaseQueue wrapper.
//
// Table columns mirror the Postgres schema in
// supabase/migrations/20260822000100_types_tables.sql and use the same
// snake_case names PostgREST already puts on the wire. Records.swift maps
// each row model's camelCase Swift properties to these columns via GRDB's
// `.convertToSnakeCase` / `.convertFromSnakeCase` column strategies, so the
// column names below are exactly what that strategy produces from the
// property names in Models/Rows.swift.
//
// Enum columns store the enum's `String` raw value (TEXT) — GRDB encodes
// them through the type's synthesized `Codable` conformance, same as any
// other leaf value, so no extra `DatabaseValueConvertible` conformance is
// needed on the enums themselves. Dates store as GRDB's native `Date`
// encoding (`.deferredToDate`, TEXT). That isn't byte-identical with
// PostgREST's fractional-second ISO 8601 wire format (see
// PostgRESTCoding.swift), but the local cache only needs a self-consistent
// round trip through SQLite — the PostgREST decoder/encoder remains the
// single source of truth for the wire format.
//
// Composite primary keys (crew_members, availability, seats, heat_reserves,
// category_rules) are declared with `t.primaryKey([...])` in the migration
// below. GRDB's `PersistableRecord` insert/update/delete/upsert operations
// introspect the live SQLite schema for primary key columns at runtime, so
// no additional per-type primary-key declaration is needed in Records.swift.

import Foundation
import GRDB

/// Wraps a GRDB `DatabaseQueue` and owns the schema migrator. One instance
/// per process; `dbQueue` is safe to share across concurrent readers.
struct AppDatabase: Sendable {
    let dbQueue: DatabaseQueue

    init(_ dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try Self.migrator.migrate(dbQueue)
    }

    /// An in-memory database. Use for tests and SwiftUI previews.
    static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    /// The on-disk database used by the running app, stored at
    /// `Application Support/Paddltir/paddltir.sqlite`.
    static func onDisk() throws -> AppDatabase {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent("Paddltir", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let dbURL = directory.appendingPathComponent("paddltir.sqlite")
        return try AppDatabase(DatabaseQueue(path: dbURL.path))
    }

    // MARK: - CRUD helpers

    /// Runs a read/write block inside a write transaction.
    @discardableResult
    func write<T>(_ updates: (Database) throws -> T) throws -> T {
        try dbQueue.write(updates)
    }

    /// Runs a read-only block.
    func read<T>(_ value: (Database) throws -> T) throws -> T {
        try dbQueue.read(value)
    }

    // MARK: - Migrations

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: Club.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("invite_code", .text).notNull()
                t.column("created_by", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime)
            }

            try db.create(table: Profile.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("club_id", .text)
                t.column("role", .text)
                t.column("display_name", .text)
                t.column("avatar_url", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime)
            }

            try db.create(table: PaddlerRow.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("club_id", .text).notNull()
                t.column("profile_id", .text)
                t.column("name", .text).notNull()
                t.column("email", .text)
                t.column("weight_kg", .double).notNull()
                t.column("preferred_side", .text).notNull()
                t.column("gender", .text).notNull()
                t.column("seat_preference", .text).notNull()
                t.column("boat_role", .text).notNull()
                t.column("archived_at", .datetime)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime)
            }

            try db.create(table: ErgTest.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("paddler_id", .text).notNull()
                t.column("tested_at", .datetime).notNull()
                t.column("metres", .integer).notNull()
                t.column("source", .text).notNull()
                t.column("recorded_by", .text)
                t.column("created_at", .datetime).notNull()
            }

            try db.create(table: Crew.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("club_id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("age_division", .text).notNull()
                t.column("category", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime)
            }

            try db.create(table: CrewMember.databaseTableName) { t in
                t.column("crew_id", .text).notNull()
                t.column("paddler_id", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.primaryKey(["crew_id", "paddler_id"])
            }

            try db.create(table: SessionRow.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("club_id", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("title", .text).notNull()
                t.column("starts_at", .datetime).notNull()
                t.column("venue", .text)
                t.column("notes", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime)
            }

            try db.create(table: Availability.databaseTableName) { t in
                t.column("session_id", .text).notNull()
                t.column("paddler_id", .text).notNull()
                t.column("status", .text).notNull()
                t.column("note", .text)
                t.column("updated_at", .datetime)
                t.primaryKey(["session_id", "paddler_id"])
            }

            try db.create(table: Race.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("session_id", .text).notNull()
                t.column("crew_id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("boat_size", .text).notNull()
                t.column("distance_m", .integer)
                t.column("sort_order", .integer).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime)
            }

            try db.create(table: Heat.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("race_id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("sort_order", .integer).notNull()
                t.column("drummer_id", .text)
                t.column("sweep_id", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime)
            }

            try db.create(table: SeatRow.databaseTableName) { t in
                t.column("heat_id", .text).notNull()
                t.column("bench", .integer).notNull()
                t.column("side", .text).notNull()
                t.column("paddler_id", .text).notNull()
                t.column("locked", .boolean).notNull()
                t.column("updated_at", .datetime)
                t.primaryKey(["heat_id", "bench", "side"])
            }

            try db.create(table: HeatReserve.databaseTableName) { t in
                t.column("heat_id", .text).notNull()
                t.column("paddler_id", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.primaryKey(["heat_id", "paddler_id"])
            }

            try db.create(table: CategoryRule.databaseTableName) { t in
                t.column("club_id", .text).notNull()
                t.column("category", .text).notNull()
                t.column("boat_size", .text).notNull()
                t.column("min_women", .integer)
                t.column("max_women", .integer)
                t.column("min_men", .integer)
                t.column("max_men", .integer)
                t.column("updated_at", .datetime)
                t.primaryKey(["club_id", "category", "boat_size"])
            }

            // Sync bookkeeping: last-synced timestamp per table, and a
            // durable outbox of pending local writes made while offline.
            try db.create(table: SyncMeta.databaseTableName) { t in
                t.primaryKey("table_name", .text)
                t.column("last_sync", .text)
            }

            try db.create(table: OutboxEntry.databaseTableName) { t in
                t.primaryKey("id", .text)
                t.column("table_name", .text).notNull()
                t.column("pk", .text).notNull()
                t.column("op", .text).notNull()
                t.column("payload", .blob).notNull()
                t.column("created_at", .text).notNull()
            }
        }

        return migrator
    }
}
