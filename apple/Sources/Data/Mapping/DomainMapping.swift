// DomainMapping.swift
// Pure, side-effect-free functions bridging the DB row models (Models/Rows.swift,
// Models/Enums.swift — the raw wire/storage shape) to PaddltirCore's
// scoring-oriented domain types (Domain/Paddler.swift, Lineup.swift, Boat.swift,
// GenderRule.swift, Enums.swift).
//
// The DB enums and PaddltirCore's enums share raw values case-for-case
// (`left/right/either`, `female/male`, `stroke/pace/engine/sprint/none`,
// `paddler/drummer/sweep`) but are distinct Swift types (see the `Row`-prefix
// note atop Models/Enums.swift), so each pair is bridged with an explicit
// switch rather than a raw-value round trip — that keeps the mapping
// exhaustive and compiler-checked if either enum ever grows a case.
//
// Two DB concepts both end up as PaddltirCore `Side`-shaped values but must
// not be conflated: `BoatSide` (the `seats.side` column — a physical seat,
// left/right only) maps to PaddltirCore's `Side`; `SidePref`
// (`paddlers.preferred_side` — left/right/either) maps to `SidePreference`.

import Foundation
import PaddltirCore

enum DomainMapping {
    // MARK: - Enum bridges

    static func side(_ pref: SidePref) -> SidePreference {
        switch pref {
        case .left: return .left
        case .right: return .right
        case .either: return .either
        }
    }

    static func gender(_ value: RowGender) -> Gender {
        switch value {
        case .female: return .female
        case .male: return .male
        }
    }

    static func seatPref(_ value: SeatPref) -> SeatPreference {
        switch value {
        case .stroke: return .stroke
        case .pace: return .pace
        case .engine: return .engine
        case .sprint: return .sprint
        case .none: return .none
        }
    }

    static func role(_ value: RowBoatRole) -> BoatRole {
        switch value {
        case .paddler: return .paddler
        case .drummer: return .drummer
        case .sweep: return .sweep
        }
    }

    /// Bridges the physical seat side (`seats.side` / `BoatSide`) — distinct
    /// from `SidePref`/`SidePreference`, a paddler's *preference*.
    static func boatSide(_ value: BoatSide) -> Side {
        switch value {
        case .left: return .left
        case .right: return .right
        }
    }

    // MARK: - Paddler / Roster

    static func paddler(row: PaddlerRow, latestErg: ErgTest?) -> Paddler {
        Paddler(
            id: PaddlerID(row.id),
            name: row.name,
            weightKg: row.weightKg,
            ergM: latestErg.map { Double($0.metres) } ?? 0,
            side: side(row.preferredSide),
            gender: gender(row.gender),
            seatPref: seatPref(row.seatPreference),
            role: role(row.boatRole)
        )
    }

    /// Each paddler's most recent erg test: max `testedAt`, `createdAt` as tiebreak.
    private static func latestErgByPaddler(_ ergs: [ErgTest]) -> [String: ErgTest] {
        var latest: [String: ErgTest] = [:]
        for erg in ergs {
            guard let current = latest[erg.paddlerId] else {
                latest[erg.paddlerId] = erg
                continue
            }
            let isNewer = erg.testedAt != current.testedAt
                ? erg.testedAt > current.testedAt
                : erg.createdAt > current.createdAt
            if isNewer { latest[erg.paddlerId] = erg }
        }
        return latest
    }

    static func roster(rows: [PaddlerRow], ergs: [ErgTest]) -> Roster {
        let latest = latestErgByPaddler(ergs)
        return Roster(rows.map { paddler(row: $0, latestErg: latest[$0.id]) })
    }

    // MARK: - GenderRule

    static func genderRule(_ rule: CategoryRule?) -> GenderRule? {
        guard let rule else { return nil }
        return GenderRule(minWomen: rule.minWomen, maxWomen: rule.maxWomen, minMen: rule.minMen, maxMen: rule.maxMen)
    }

    // MARK: - Boat

    static func boat(size: BoatSize) -> Boat {
        switch size {
        case .small: return .small
        case .standard: return .standard
        }
    }

    // MARK: - Lineup

    static func lineup(heat: Heat, seats: [SeatRow], boat: Boat) -> Lineup {
        let assignments = seats.map { seat in
            SeatAssignment(
                bench: seat.bench,
                side: boatSide(seat.side),
                paddlerId: PaddlerID(seat.paddlerId),
                locked: seat.locked
            )
        }
        return Lineup(
            boat: boat,
            drummerId: heat.drummerId.map(PaddlerID.init),
            sweepId: heat.sweepId.map(PaddlerID.init),
            assignments: assignments
        )
    }
}
