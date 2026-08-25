// Rows.swift
// Codable mirrors of the Supabase/Postgres tables in
// supabase/migrations/20260822000100_types_tables.sql. One struct per table
// (every column modelled), decoded/encoded exclusively through
// `PostgREST.decoder` / `PostgREST.encoder` (see PostgRESTCoding.swift),
// which supplies `.convertFromSnakeCase` key mapping and PostgREST-flavoured
// date parsing — so these types rely on plain camelCase properties instead
// of hand-written CodingKeys.
//
// `optimize_cache` is server-only and intentionally not modelled here.
//
// Row types are suffixed `Row` (or otherwise disambiguated, e.g. `SessionRow`,
// `SeatRow`, `PaddlerRow`) where the bare table name would collide with an
// existing PaddltirCore domain type (`Paddler`, `Gender`, `BoatRole`, ...).
// These row structs are the raw wire/storage shape, distinct from
// PaddltirCore's scoring-oriented domain model.

import Foundation

/// `clubs`
struct Club: Codable, Hashable, Sendable {
    var id: String
    var name: String
    var inviteCode: String
    var createdBy: String?
    var createdAt: Date
    var updatedAt: Date?
}

/// `profiles`
struct Profile: Codable, Hashable, Sendable {
    var id: String
    var clubId: String?
    var role: UserRole?
    var displayName: String?
    var avatarUrl: String?
    var createdAt: Date
    var updatedAt: Date?
}

/// `paddlers`
struct PaddlerRow: Codable, Hashable, Sendable {
    var id: String
    var clubId: String
    var profileId: String?
    var name: String
    var email: String?
    var weightKg: Double
    var preferredSide: SidePref
    var gender: RowGender
    var seatPreference: SeatPref
    var boatRole: RowBoatRole
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date?
}

/// `erg_tests`
struct ErgTest: Codable, Hashable, Sendable {
    var id: String
    var paddlerId: String
    var testedAt: Date
    var metres: Int
    var source: ErgSource
    var recordedBy: String?
    var createdAt: Date
}

/// `crews`
struct Crew: Codable, Hashable, Sendable {
    var id: String
    var clubId: String
    var name: String
    /// Free-text, constrained by a DB check (not a Postgres enum):
    /// '16U','18U','24U','Premier','Senior A','Senior B','Senior C'.
    var ageDivision: String
    var category: CrewCategory
    var createdAt: Date
    var updatedAt: Date?
}

/// `crew_members` — composite primary key (crewId, paddlerId).
struct CrewMember: Codable, Hashable, Sendable {
    var crewId: String
    var paddlerId: String
    var createdAt: Date
}

/// `sessions`
struct SessionRow: Codable, Hashable, Sendable {
    var id: String
    var clubId: String
    var kind: SessionKind
    var title: String
    var startsAt: Date
    var venue: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date?
}

/// `availability` — composite primary key (sessionId, paddlerId).
struct Availability: Codable, Hashable, Sendable {
    var sessionId: String
    var paddlerId: String
    var status: AvailabilityStatus
    var note: String?
    var updatedAt: Date?
}

/// `races`
struct Race: Codable, Hashable, Sendable {
    var id: String
    var sessionId: String
    var crewId: String
    var name: String
    var boatSize: BoatSize
    var distanceM: Int?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date?
}

/// `heats`
struct Heat: Codable, Hashable, Sendable {
    var id: String
    var raceId: String
    var name: String
    var sortOrder: Int
    var drummerId: String?
    var sweepId: String?
    var createdAt: Date
    var updatedAt: Date?
}

/// `seats` — composite primary key (heatId, bench, side); also unique on (heatId, paddlerId).
struct SeatRow: Codable, Hashable, Sendable {
    var heatId: String
    var bench: Int
    var side: BoatSide
    var paddlerId: String
    var locked: Bool
    var updatedAt: Date?
}

/// `heat_reserves` — composite primary key (heatId, paddlerId).
struct HeatReserve: Codable, Hashable, Sendable {
    var heatId: String
    var paddlerId: String
    var createdAt: Date
}

/// `category_rules` — composite primary key (clubId, category, boatSize).
struct CategoryRule: Codable, Hashable, Sendable {
    var clubId: String
    var category: CrewCategory
    var boatSize: BoatSize
    var minWomen: Int?
    var maxWomen: Int?
    var minMen: Int?
    var maxMen: Int?
    var updatedAt: Date?
}
