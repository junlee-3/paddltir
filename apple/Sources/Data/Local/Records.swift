// Records.swift
// GRDB `FetchableRecord`/`PersistableRecord` conformances for the row models
// in Models/Rows.swift, plus two local-only record types (`SyncMeta`,
// `OutboxEntry`) backing the sync bookkeeping tables created in
// AppDatabase's migrator.
//
// Column naming: the row models are plain `Codable` structs with camelCase
// properties, decoded/encoded against PostgREST JSON via
// `.convertFromSnakeCase` / `.convertToSnakeCase` (see PostgRESTCoding.swift)
// — they carry no explicit `CodingKeys`. GRDB's default `FetchableRecord`/
// `PersistableRecord` implementations for `Decodable`/`Encodable` types read
// and write columns keyed by those same coding keys, so pointing GRDB at the
// same `.convertToSnakeCase` / `.convertFromSnakeCase` column strategy
// reuses the row models unmodified and lines up column names with the
// snake_case table columns declared in AppDatabase's migrator (which in turn
// match the wire shape PostgREST uses) — camelCase in Swift, snake_case in
// both SQLite and Postgres.
import Foundation
import GRDB

/// Shared column-naming strategy for every local-store record: camelCase
/// Swift properties map to snake_case SQLite columns.
protocol SnakeCaseRecord: Codable, FetchableRecord, PersistableRecord {}

extension SnakeCaseRecord {
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }
}

// MARK: - Row models (Models/Rows.swift)

extension Club: SnakeCaseRecord {
    static let databaseTableName = "clubs"
}

extension Profile: SnakeCaseRecord {
    static let databaseTableName = "profiles"
}

extension PaddlerRow: SnakeCaseRecord {
    static let databaseTableName = "paddlers"
}

extension ErgTest: SnakeCaseRecord {
    static let databaseTableName = "erg_tests"
}

extension Crew: SnakeCaseRecord {
    static let databaseTableName = "crews"
}

/// Composite primary key (crew_id, paddler_id) — declared on the table in
/// AppDatabase's migrator; GRDB introspects it from the live schema.
extension CrewMember: SnakeCaseRecord {
    static let databaseTableName = "crew_members"
}

extension SessionRow: SnakeCaseRecord {
    static let databaseTableName = "sessions"
}

/// Composite primary key (session_id, paddler_id).
extension Availability: SnakeCaseRecord {
    static let databaseTableName = "availability"
}

extension Race: SnakeCaseRecord {
    static let databaseTableName = "races"
}

extension Heat: SnakeCaseRecord {
    static let databaseTableName = "heats"
}

/// Composite primary key (heat_id, bench, side); also unique on
/// (heat_id, paddler_id) per the Postgres schema (not separately enforced
/// in SQLite here).
extension SeatRow: SnakeCaseRecord {
    static let databaseTableName = "seats"
}

/// Composite primary key (heat_id, paddler_id).
extension HeatReserve: SnakeCaseRecord {
    static let databaseTableName = "heat_reserves"
}

/// Composite primary key (club_id, category, boat_size).
extension CategoryRule: SnakeCaseRecord {
    static let databaseTableName = "category_rules"
}

// MARK: - Local-only sync bookkeeping

/// Tracks the last successful sync timestamp per table (ISO 8601 text, or
/// nil if that table has never synced).
struct SyncMeta: Codable, Hashable, Sendable {
    var tableName: String
    var lastSync: String?
}

extension SyncMeta: SnakeCaseRecord {
    static let databaseTableName = "sync_meta"
}

/// A pending local write awaiting sync to the server.
struct OutboxEntry: Codable, Hashable, Sendable {
    var id: String
    var tableName: String
    var pk: String
    var op: String
    var payload: Data
    var createdAt: String
}

extension OutboxEntry: SnakeCaseRecord {
    static let databaseTableName = "outbox"
}
