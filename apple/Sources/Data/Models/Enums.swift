// Enums.swift
// Swift mirrors of the Postgres enum types defined in
// supabase/migrations/20260822000100_types_tables.sql. Raw values match the
// lowercase Postgres labels exactly, since PostgREST serializes enums as
// their bare label string (no snake_case key conversion applies to values).
//
// `RowGender` and `RowBoatRole` carry a `Row` prefix (matching the `Row`
// suffix used on colliding row structs, e.g. `PaddlerRow`) because
// PaddltirCore already defines its own `Gender` and `BoatRole` domain enums
// with the same cases. Both live in the same compiled app module (PaddltirCore
// is a dependency, not a separate namespace for lookup purposes), so the
// unprefixed names would shadow PaddltirCore's public types wherever this
// target imports PaddltirCore, breaking call sites like SeatTile's public
// `Gender` parameter. Every other enum below matches its DB type name
// directly since no such collision exists.

import Foundation

/// `user_role`
enum UserRole: String, Codable, Hashable, Sendable {
    case headCoach = "head_coach"
    case coach
    case paddler
}

/// `side_pref`
enum SidePref: String, Codable, Hashable, Sendable {
    case left
    case right
    case either
}

/// `boat_side`
enum BoatSide: String, Codable, Hashable, Sendable {
    case left
    case right
}

/// `gender`
enum RowGender: String, Codable, Hashable, Sendable {
    case female
    case male
}

/// `seat_pref`
enum SeatPref: String, Codable, Hashable, Sendable {
    case stroke
    case pace
    case engine
    case sprint
    case none
}

/// `boat_role`
enum RowBoatRole: String, Codable, Hashable, Sendable {
    case paddler
    case drummer
    case sweep
}

/// `boat_size`
enum BoatSize: String, Codable, Hashable, Sendable {
    case small
    case standard
}

/// `crew_category`
enum CrewCategory: String, Codable, Hashable, Sendable {
    case open
    case women
    case mixed
}

/// `session_kind`
enum SessionKind: String, Codable, Hashable, Sendable {
    case training
    case raceDay = "race_day"
}

/// `availability_status`
enum AvailabilityStatus: String, Codable, Hashable, Sendable {
    case `in`
    case out
    case maybe
}

/// `erg_source`
enum ErgSource: String, Codable, Hashable, Sendable {
    case coach
    case selfReported = "self"
}
