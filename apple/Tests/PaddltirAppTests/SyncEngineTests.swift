// SyncEngineTests.swift
// Exercises SyncEngine end-to-end against FakeRemote — an in-memory
// RemoteStore held by this file, no network involved. Covers: pulling
// remote rows into GRDB through the row models (never raw JSON -> GRDB),
// `since` being respected on re-sync, pushing + clearing the outbox, and
// the LWW rule (outbox entries win until pushed).

import Foundation
import GRDB
import Testing
@testable import Paddltir

/// An in-memory `RemoteStore`. Holds each table's current row set as raw
/// PostgREST JSON, and filters `pull(since:)` by decoding just enough of
/// each row (`updated_at`) to compare — mirroring how a real PostgREST
/// endpoint would filter server-side, without any network I/O.
actor FakeRemote: RemoteStore {
    private struct RowTimestamp: Decodable {
        let updatedAt: Date
    }

    let clubID: String?
    private var rowsByTable: [String: [Data]] = [:]
    private(set) var pushedByTable: [String: [Data]] = [:]

    init(clubID: String? = "club-1") {
        self.clubID = clubID
    }

    /// Test setup: replaces this table's full remote row set.
    func seed(_ table: String, rows: [Data]) {
        rowsByTable[table] = rows
    }

    func pull(table: String, since: Date?) async throws -> [Data] {
        let rows = rowsByTable[table] ?? []
        guard let since else { return rows }
        return try rows.filter { json in
            try PostgREST.decoder.decode(RowTimestamp.self, from: json).updatedAt > since
        }
    }

    func push(table: String, rows: [Data]) async throws {
        pushedByTable[table, default: []].append(contentsOf: rows)
    }
}

@Suite struct SyncEngineTests {
    private let clubId = "22222222-2222-2222-2222-222222222222"
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func paddler(id: String, name: String, updatedAt: Date) -> PaddlerRow {
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
            createdAt: updatedAt,
            updatedAt: updatedAt
        )
    }

    private func paddlerJSON(id: String, name: String, updatedAt: Date) throws -> Data {
        try PostgREST.encoder.encode(paddler(id: id, name: name, updatedAt: updatedAt))
    }

    // MARK: - Pull

    @Test func syncAllPullsRowsIntoGRDBThroughTheRowModel() async throws {
        let appDB = try AppDatabase.inMemory()
        let remote = FakeRemote(clubID: clubId)
        await remote.seed("paddlers", rows: [
            try paddlerJSON(id: "p-1", name: "Alice", updatedAt: t0),
            try paddlerJSON(id: "p-2", name: "Bob", updatedAt: t0.addingTimeInterval(10)),
        ])

        try await SyncEngine(db: appDB, remote: remote).syncAll()

        let paddlers = try appDB.read { db in try PaddlerRow.fetchAll(db) }
        #expect(paddlers.count == 2)
        let alice = try appDB.read { db in try PaddlerRow.fetchOne(db, key: "p-1") }
        #expect(alice?.name == "Alice")
        // Decoded through PaddlerRow (Swift Date), not raw JSON bytes: the
        // date round-trips as a real `Date`, comparable to the source value.
        #expect(alice?.updatedAt == t0)

        let lastSync = try appDB.read { db in try SyncMeta.fetchOne(db, key: "paddlers")?.lastSync }
        #expect(lastSync == PostgREST.formatDate(t0.addingTimeInterval(10)))
    }

    @Test func reSyncOnlyPullsRowsNewerThanLastSync() async throws {
        let appDB = try AppDatabase.inMemory()
        let remote = FakeRemote(clubID: clubId)
        await remote.seed("paddlers", rows: [
            try paddlerJSON(id: "p-1", name: "Alice", updatedAt: t0),
            try paddlerJSON(id: "p-2", name: "Bob", updatedAt: t0),
        ])
        let engine = SyncEngine(db: appDB, remote: remote)
        try await engine.syncAll()

        let lastSync = try appDB.read { db in try SyncMeta.fetchOne(db, key: "paddlers")?.lastSync }
        #expect(lastSync == PostgREST.formatDate(t0))

        // FakeRemote itself respects `since`: with Bob's updated_at bumped
        // and Alice's left untouched, only Bob is newer than the recorded
        // last_sync.
        let bumped = t0.addingTimeInterval(3600)
        await remote.seed("paddlers", rows: [
            try paddlerJSON(id: "p-1", name: "Alice", updatedAt: t0),
            try paddlerJSON(id: "p-2", name: "Bob Renamed", updatedAt: bumped),
        ])
        let onlyNewer = try await remote.pull(table: "paddlers", since: t0)
        #expect(onlyNewer.count == 1)

        // And end-to-end through the engine: re-syncing only applies Bob's
        // change. Prove Alice's row genuinely wasn't re-pulled (not just
        // re-written with the same values) by mutating it locally first —
        // if the stale remote row were incorrectly pulled again, it would
        // clobber this local-only edit.
        try appDB.write { db in
            var localAlice = try #require(try PaddlerRow.fetchOne(db, key: "p-1"))
            localAlice.name = "Alice (local, untouched by re-sync)"
            try localAlice.update(db)
        }

        try await engine.syncAll()

        let bob = try appDB.read { db in try PaddlerRow.fetchOne(db, key: "p-2") }
        #expect(bob?.name == "Bob Renamed")
        let alice = try appDB.read { db in try PaddlerRow.fetchOne(db, key: "p-1") }
        #expect(alice?.name == "Alice (local, untouched by re-sync)")

        let advancedSync = try appDB.read { db in try SyncMeta.fetchOne(db, key: "paddlers")?.lastSync }
        #expect(advancedSync == PostgREST.formatDate(bumped))
    }

    // MARK: - Push

    @Test func syncAllPushesOutboxEntriesAndClearsThem() async throws {
        let appDB = try AppDatabase.inMemory()
        let remote = FakeRemote(clubID: clubId)
        let payload = try paddlerJSON(id: "p-9", name: "Local Edit", updatedAt: t0.addingTimeInterval(5))

        try appDB.write { db in
            try Outbox.enqueue(db: db, table: "paddlers", pk: "p-9", op: "update", payload: payload)
        }
        #expect(try appDB.read { db in try OutboxEntry.fetchCount(db) } == 1)

        try await SyncEngine(db: appDB, remote: remote).syncAll()

        let pushed = await remote.pushedByTable["paddlers"]
        #expect(pushed?.count == 1)
        #expect(pushed?.first == payload)

        let remainingOutbox = try appDB.read { db in try OutboxEntry.fetchCount(db) }
        #expect(remainingOutbox == 0)
    }

    // MARK: - LWW

    @Test func staleRemoteRowDoesNotClobberQueuedLocalEdit() async throws {
        let appDB = try AppDatabase.inMemory()
        let remote = FakeRemote(clubID: clubId)

        // A local edit exists in GRDB and is queued in the outbox, not yet
        // pushed.
        let localEditedAt = t0.addingTimeInterval(120)
        let localRow = paddler(id: "p-1", name: "Local Edit (queued)", updatedAt: localEditedAt)
        try appDB.write { db in
            try localRow.insert(db)
            try Outbox.enqueue(
                db: db,
                table: "paddlers",
                pk: "p-1",
                op: "update",
                payload: try PostgREST.encoder.encode(localRow)
            )
        }

        // The remote has an older version of the same row. This is a first
        // sync (`since == nil`), so it would normally pull straight in.
        await remote.seed("paddlers", rows: [
            try paddlerJSON(id: "p-1", name: "Stale Remote Name", updatedAt: t0),
        ])

        try await SyncEngine(db: appDB, remote: remote).syncAll()

        // The pending outbox entry protects the local edit from the pull.
        let fetched = try appDB.read { db in try PaddlerRow.fetchOne(db, key: "p-1") }
        #expect(fetched?.name == "Local Edit (queued)")

        // The queued edit is still pushed and the outbox still drains, even
        // though the pull for that row was skipped.
        let pushed = await remote.pushedByTable["paddlers"]
        #expect(pushed?.count == 1)
        let remainingOutbox = try appDB.read { db in try OutboxEntry.fetchCount(db) }
        #expect(remainingOutbox == 0)
    }
}
