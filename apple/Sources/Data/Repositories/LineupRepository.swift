// LineupRepository.swift
// Async, GRDB-backed, offline-first repository over `heats` (+ `seats`,
// `heat_reserves`) — what the Lineup editor consumes. See
// SquadRepository.swift's header for the read/write split the other three
// repositories follow.
//
// `placementRequest(heatId:)` is the one non-trivial assembly: it walks
// heat -> race -> crew -> crew_members -> paddlers/erg_tests, plus the race's
// category_rule and the heat's own seats/drummer/sweep, and maps the result
// through `DomainMapping` into a `PaddltirCore.PlacementRequest` — everything
// `Greedy.autoFill` (the editor's Auto-fill/Suggest action) needs. The FK
// path mirrors supabase/migrations/20260822000100_types_tables.sql:
// `races.crew_id -> crews.id`, `crew_members.crew_id/.paddler_id`,
// `category_rules` keyed by `(club_id, category, boat_size)` (crew supplies
// `club_id`/`category`, race supplies `boat_size`), and
// `heats.race_id`/`.drummer_id`/`.sweep_id`.

import Foundation
import GRDB
import PaddltirCore

struct LineupRepository: Sendable {
    let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
    }

    /// A race's heats, in their configured display order.
    func heats(raceId: String) async throws -> [Heat] {
        try db.read { db in
            try Heat
                .filter(Column("race_id") == raceId)
                .order(Column("sort_order"))
                .fetchAll(db)
        }
    }

    /// A heat with its seats and reserves, or `nil` if `id` doesn't exist.
    func heat(id: String) async throws -> (heat: Heat, seats: [SeatRow], reserves: [HeatReserve])? {
        try db.read { db in
            guard let heat = try Heat.fetchOne(db, key: id) else { return nil }
            let seats = try SeatRow.filter(Column("heat_id") == id).fetchAll(db)
            let reserves = try HeatReserve.filter(Column("heat_id") == id).fetchAll(db)
            return (heat, seats, reserves)
        }
    }

    /// Replaces every seat assignment for `heatId` with `seats`, in one
    /// transaction: rows are diffed against the current seats by (bench,
    /// side) so a seat the editor didn't touch generates no churn, a seat
    /// dropped from the new set is deleted (and enqueued as a delete), and
    /// every seat in the new set is written (and enqueued) — matching
    /// `setMembers`'s diff shape in CrewRepository.
    func saveSeats(heatId: String, seats: [SeatRow]) async throws {
        struct BenchSide: Hashable { let bench: Int; let side: BoatSide }

        try db.write { db in
            let existing = try SeatRow.filter(Column("heat_id") == heatId).fetchAll(db)
            let newKeys = Set(seats.map { BenchSide(bench: $0.bench, side: $0.side) })

            for seat in existing where !newKeys.contains(BenchSide(bench: seat.bench, side: seat.side)) {
                try seat.delete(db)
                try Outbox.enqueue(
                    db: db,
                    table: SeatRow.databaseTableName,
                    pk: seat.syncPrimaryKey,
                    op: "delete",
                    payload: try PostgREST.encoder.encode(seat)
                )
            }

            for var seat in seats {
                seat.heatId = heatId
                try seat.upsert(db)
                try Outbox.enqueue(
                    db: db,
                    table: SeatRow.databaseTableName,
                    pk: seat.syncPrimaryKey,
                    op: "update",
                    payload: try PostgREST.encoder.encode(seat)
                )
            }
        }
    }

    /// Assembles everything `Greedy.autoFill` (and the other placement
    /// algorithms) need for `heatId`: the race's crew as the candidate
    /// roster, the race's category+boat-size rule, the heat's drummer/sweep,
    /// and its current seats (as both the locked subset and the reference
    /// lineup for the `moves` tie-break). Returns `nil` if the heat — or
    /// anything it transitively references (race, crew) — doesn't exist.
    func placementRequest(heatId: String) async throws -> PlacementRequest? {
        try db.read { db in
            guard let heat = try Heat.fetchOne(db, key: heatId) else { return nil }
            guard let race = try Race.fetchOne(db, key: heat.raceId) else { return nil }
            guard let crew = try Crew.fetchOne(db, key: race.crewId) else { return nil }

            let memberIds = try CrewMember
                .filter(Column("crew_id") == crew.id)
                .fetchAll(db)
                .map(\.paddlerId)
            let rows = try PaddlerRow.filter(memberIds.contains(Column("id"))).fetchAll(db)
            let ergs = try ErgTest.filter(memberIds.contains(Column("paddler_id"))).fetchAll(db)
            let roster = DomainMapping.roster(rows: rows, ergs: ergs)

            let categoryRuleKey: [String: (any DatabaseValueConvertible)?] = [
                "club_id": crew.clubId,
                "category": crew.category.rawValue,
                "boat_size": race.boatSize.rawValue,
            ]
            let categoryRule = try CategoryRule.fetchOne(db, key: categoryRuleKey)
            let rule = DomainMapping.genderRule(categoryRule)

            let seats = try SeatRow.filter(Column("heat_id") == heatId).fetchAll(db)
            let boat = DomainMapping.boat(size: race.boatSize)
            let currentLineup = DomainMapping.lineup(heat: heat, seats: seats, boat: boat)

            return PlacementRequest(
                boat: boat,
                roster: roster,
                candidates: roster.ids,
                drummerId: heat.drummerId.map(PaddlerID.init),
                sweepId: heat.sweepId.map(PaddlerID.init),
                locked: currentLineup.assignments.filter(\.locked),
                rule: rule,
                current: currentLineup
            )
        }
    }

    /// Adds a heat to a race; `sort_order` is the next free slot.
    func createHeat(raceId: String, name: String) async throws -> Heat {
        try db.write { db in
            let order = try Heat.filter(Column("race_id") == raceId).fetchCount(db)
            let row = Heat(id: UUID().uuidString, raceId: raceId, name: name, sortOrder: order,
                           drummerId: nil, sweepId: nil, createdAt: Date(), updatedAt: nil)
            try row.insert(db)
            try Outbox.enqueue(db: db, table: Heat.databaseTableName, pk: row.syncPrimaryKey,
                               op: "insert", payload: try PostgREST.encoder.encode(row))
            return row
        }
    }

    /// Updates a heat's name + drummer/sweep (the lineup editor's non-seat state).
    func saveHeat(heatId: String, name: String, drummerId: String?, sweepId: String?) async throws {
        try db.write { db in
            guard var row = try Heat.fetchOne(db, key: heatId) else { return }
            row.name = name; row.drummerId = drummerId; row.sweepId = sweepId; row.updatedAt = Date()
            try row.update(db)
            try Outbox.enqueue(db: db, table: Heat.databaseTableName, pk: row.syncPrimaryKey,
                               op: "update", payload: try PostgREST.encoder.encode(row))
        }
    }
}
