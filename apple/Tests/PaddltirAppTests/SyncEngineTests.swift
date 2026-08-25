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
    private(set) var deletedByTable: [String: [Data]] = [:]
    /// Table names in the order they received a non-empty push or delete —
    /// lets tests assert parent-before-child drain ordering.
    private(set) var writeLog: [String] = []

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
        guard !rows.isEmpty else { return }
        pushedByTable[table, default: []].append(contentsOf: rows)
        writeLog.append(table)
    }

    func delete(table: String, rows: [Data]) async throws {
        guard !rows.isEmpty else { return }
        deletedByTable[table, default: []].append(contentsOf: rows)
        writeLog.append(table)
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

    // MARK: - Delete routing (deletes must not resurrect on the server)

    /// A `"delete"` outbox entry is routed to `remote.delete`, never
    /// `remote.push` — pushing it would upsert the row the coach removed and,
    /// for trigger-bumped tables, pull it back on the next sync.
    @Test func syncAllRoutesDeletesToDeleteNotPush() async throws {
        let appDB = try AppDatabase.inMemory()
        let remote = FakeRemote(clubID: clubId)
        let payload = Data("removed-member".utf8)
        try appDB.write { db in
            try Outbox.enqueue(db: db, table: "crew_members", pk: "c-1|p-1", op: "delete", payload: payload)
        }

        try await SyncEngine(db: appDB, remote: remote).syncAll()

        let deleted = await remote.deletedByTable["crew_members"]
        #expect(deleted == [payload])
        let pushed = await remote.pushedByTable["crew_members"]
        #expect(pushed == nil) // never upserted
        #expect(try appDB.read { db in try OutboxEntry.fetchCount(db) } == 0)
    }

    /// The outbox drains parents before children (SyncableTable.all order),
    /// regardless of insertion order, so a queued child never reaches the
    /// server ahead of the parent it references.
    @Test func drainPushesParentTablesBeforeChildren() async throws {
        let appDB = try AppDatabase.inMemory()
        let remote = FakeRemote(clubID: clubId)
        // Child enqueued first (earlier created_at) to prove ordering follows
        // the table registry, not created_at / hash order.
        try appDB.write { db in
            try Outbox.enqueue(db: db, table: "crew_members", pk: "c-1|p-1", op: "insert", payload: Data("m".utf8))
        }
        try appDB.write { db in
            try Outbox.enqueue(db: db, table: "crews", pk: "c-1", op: "insert", payload: Data("c".utf8))
        }

        try await SyncEngine(db: appDB, remote: remote).syncAll()

        let log = await remote.writeLog
        let crews = try #require(log.firstIndex(of: "crews"))
        let members = try #require(log.firstIndex(of: "crew_members"))
        #expect(crews < members)
    }

    // MARK: - Toggle collapse (net final op wins)

    /// remove-then-re-add of the same key before any sync pushes only the
    /// final insert — the superseded delete never fires, so the row isn't
    /// wrongly removed server-side.
    @Test func togglingAKeyToReAddPushesOnlyTheFinalUpsert() async throws {
        let appDB = try AppDatabase.inMemory()
        let remote = FakeRemote(clubID: clubId)
        try appDB.write { db in
            try OutboxEntry(id: "e1", tableName: "crew_members", pk: "c-1|p-1", op: "delete",
                            payload: Data("old".utf8), createdAt: PostgREST.formatDate(t0)).insert(db)
            try OutboxEntry(id: "e2", tableName: "crew_members", pk: "c-1|p-1", op: "insert",
                            payload: Data("new".utf8), createdAt: PostgREST.formatDate(t0.addingTimeInterval(1))).insert(db)
        }

        try await SyncEngine(db: appDB, remote: remote).syncAll()

        #expect(await remote.pushedByTable["crew_members"] == [Data("new".utf8)])
        #expect(await remote.deletedByTable["crew_members"] == nil)
        #expect(try appDB.read { db in try OutboxEntry.fetchCount(db) } == 0)
    }

    /// add-then-remove of the same key before any sync pushes only the final
    /// delete — the superseded insert never fires.
    @Test func togglingAKeyToDeletionPushesOnlyTheFinalDelete() async throws {
        let appDB = try AppDatabase.inMemory()
        let remote = FakeRemote(clubID: clubId)
        try appDB.write { db in
            try OutboxEntry(id: "e1", tableName: "crew_members", pk: "c-1|p-1", op: "insert",
                            payload: Data("added".utf8), createdAt: PostgREST.formatDate(t0)).insert(db)
            try OutboxEntry(id: "e2", tableName: "crew_members", pk: "c-1|p-1", op: "delete",
                            payload: Data("gone".utf8), createdAt: PostgREST.formatDate(t0.addingTimeInterval(1))).insert(db)
        }

        try await SyncEngine(db: appDB, remote: remote).syncAll()

        #expect(await remote.deletedByTable["crew_members"] == [Data("gone".utf8)])
        #expect(await remote.pushedByTable["crew_members"] == nil)
        #expect(try appDB.read { db in try OutboxEntry.fetchCount(db) } == 0)
    }
}
