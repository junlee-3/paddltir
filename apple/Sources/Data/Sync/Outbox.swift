// Outbox.swift
// Queues local writes (made while offline, or simply ahead of the next
// foreground sync) so SyncEngine can push them to the remote later. See
// SyncEngine.swift for how outbox entries interact with rows pulled from
// the remote in the meantime (outbox entries win until pushed).

import Foundation
import GRDB

enum Outbox {
    /// Records one pending local write against `table`, to be pushed on the
    /// next `SyncEngine.syncAll()`.
    ///
    /// - Parameters:
    ///   - db: The write transaction to enqueue into — call this inside the
    ///     same `AppDatabase.write { db in ... }` block as the local
    ///     mutation itself, so the edit and its outbox entry commit
    ///     atomically.
    ///   - table: The row's table name (e.g. `PaddlerRow.databaseTableName`).
    ///   - pk: The row's primary key, encoded the same way
    ///     `SyncableRow.syncPrimaryKey` encodes it for that table (a bare
    ///     id for single-column keys; composite keys joined with "|") — so
    ///     `SyncEngine`'s pull-vs-outbox check can match this entry back to
    ///     the row it guards.
    ///   - op: `"insert"`, `"update"`, or `"delete"`.
    ///   - payload: The row encoded via `PostgREST.encoder`, ready to hand
    ///     to `RemoteStore.push(table:rows:)` unchanged.
    static func enqueue(
        db: Database,
        table: String,
        pk: String,
        op: String,
        payload: Data
    ) throws {
        let entry = OutboxEntry(
            id: UUID().uuidString,
            tableName: table,
            pk: pk,
            op: op,
            payload: payload,
            createdAt: PostgREST.formatDate(Date())
        )
        try entry.insert(db)
    }
}
