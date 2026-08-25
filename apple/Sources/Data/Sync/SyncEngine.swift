// SyncEngine.swift
// Deliberately simple offline sync: mirror ONE club's rows. This is not a
// conflict-resolution engine — see the LWW rule below.
//
// `syncAll()`:
//  1. Pulls, per table (see SyncableTable.all): rows where
//     `updated_at > sync_meta.last_sync`, decoded from PostgREST wire JSON
//     into that table's row model (`PostgREST.decoder`, so `Date` fields
//     parse correctly), then upserted into GRDB as the *row model*
//     (`insert(onConflict: .replace)`) — never as raw JSON bytes, so GRDB
//     re-encodes the `Date` through its own storage. See SyncableTable.swift
//     for why that distinction matters. `sync_meta.last_sync` advances to
//     the max pulled `updated_at` for that table.
//  2. Drains the outbox: pushes every queued local write, grouped by table,
//     and deletes each entry once its push succeeds.
//
// LWW rule (kept intentionally simple, per the spec): **outbox entries win
// until they're pushed.** While pulling, any row whose primary key
// currently has a pending outbox entry for that table is skipped — the
// local edit already queued for push is left alone rather than being
// clobbered by whatever the server had before that push lands, regardless
// of the two rows' relative `updated_at`. `sync_meta.last_sync` still
// advances past skipped rows: we've seen them, our own push will supersede
// them on the server, and re-pulling the same row forever would be wasted
// work. Once the outbox drains, the next sync pulls normally.

import Foundation
import GRDB

struct SyncEngine: Sendable {
    let db: AppDatabase
    let remote: any RemoteStore

    init(db: AppDatabase, remote: any RemoteStore) {
        self.db = db
        self.remote = remote
    }

    func syncAll() async throws {
        guard await remote.clubID != nil else { return }

        for table in SyncableTable.all {
            try await pull(table)
        }
        try await drainOutbox()
    }

    // MARK: - Pull

    private func pull(_ table: SyncableTable) async throws {
        let lastSync = try readLastSync(table: table.tableName)
        let rows = try await remote.pull(table: table.tableName, since: lastSync)
        guard !rows.isEmpty else { return }

        let decoded = try rows.map { try table.decode($0) }
        guard let maxSynced = decoded.map(\.syncedAt).max() else { return }

        try db.write { db in
            let pendingPks = try Set(
                OutboxEntry
                    .filter(Column("table_name") == table.tableName)
                    .fetchAll(db)
                    .map(\.pk)
            )
            for row in decoded where !pendingPks.contains(row.pk) {
                try row.upsert(db)
            }

            let advanced = lastSync.map { max($0, maxSynced) } ?? maxSynced
            try writeLastSync(db: db, table: table.tableName, lastSync: advanced)
        }
    }

    private func readLastSync(table: String) throws -> Date? {
        try db.read { db in
            try SyncMeta.fetchOne(db, key: table)?.lastSync.flatMap(PostgREST.parseDate)
        }
    }

    private func writeLastSync(db: Database, table: String, lastSync: Date) throws {
        if var meta = try SyncMeta.fetchOne(db, key: table) {
            meta.lastSync = PostgREST.formatDate(lastSync)
            try meta.update(db)
        } else {
            try SyncMeta(tableName: table, lastSync: PostgREST.formatDate(lastSync)).insert(db)
        }
    }

    // MARK: - Push

    private func drainOutbox() async throws {
        let entries = try db.read { db in
            try OutboxEntry.order(Column("created_at")).fetchAll(db)
        }
        guard !entries.isEmpty else { return }

        let byTable = Dictionary(grouping: entries, by: \.tableName)
        for (table, tableEntries) in byTable {
            try await remote.push(table: table, rows: tableEntries.map(\.payload))
            try db.write { db in
                for entry in tableEntries {
                    try entry.delete(db)
                }
            }
        }
    }
}
