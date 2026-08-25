// PaddlerWithErg.swift
// The local equivalent of the Supabase `paddlers_with_power` view: a
// paddler row paired with their most recent erg test (if any), assembled
// entirely in GRDB + Swift rather than a second SQL view — see
// AppDatabase.swift's migrator, which has no such view locally.
//
// `SquadRepository` and `CrewRepository` both fetch a `PaddlerRow` set and a
// matching `ErgTest` set, then call `join(rows:ergs:)` to pair them up using
// the exact same "latest erg" tie-break (max `testedAt`, `createdAt` as a
// second tiebreak) that `DomainMapping.roster(rows:ergs:)` already applies
// when building a `PaddltirCore.Roster` — `DomainMapping.latestErgByPaddler`
// is shared between both call sites so that rule lives in exactly one place.

import Foundation
import PaddltirCore

/// A paddler row joined to their latest erg test, plus the mapped
/// `PaddltirCore.Paddler` domain type feature screens render against.
struct PaddlerWithErg: Hashable, Sendable {
    var row: PaddlerRow
    var latestErg: ErgTest?

    /// The erg-aware domain type, via `DomainMapping.paddler(row:latestErg:)`.
    var paddler: Paddler {
        DomainMapping.paddler(row: row, latestErg: latestErg)
    }
}

extension PaddlerWithErg {
    /// Joins `rows` to their latest test in `ergs`, preserving `rows`' order.
    /// `ergs` may contain tests for paddlers outside `rows` (harmless — they
    /// only contribute if their `paddlerId` matches a row) and tests for the
    /// same paddler at multiple dates (only the latest is kept, per paddler).
    static func join(rows: [PaddlerRow], ergs: [ErgTest]) -> [PaddlerWithErg] {
        let latest = DomainMapping.latestErgByPaddler(ergs)
        return rows.map { PaddlerWithErg(row: $0, latestErg: latest[$0.id]) }
    }
}
