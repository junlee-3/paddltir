// RemoteStore.swift
// Abstraction over the remote Postgres/PostgREST endpoint that SyncEngine
// pulls from and pushes to.
//
// Rows cross this boundary as raw PostgREST JSON (`Data`) rather than typed
// Swift models, so the protocol — and SyncEngine's call sites — stay
// table-agnostic. Decoding a row's `Data` into its specific Swift type (and
// therefore its `Date` fields, via `PostgREST.decoder`) happens per table on
// the engine side; see SyncableTable.swift.

import Foundation

/// A remote store scoped to at most one club at a time — this app's sync
/// model deliberately mirrors a single club's rows, not a general
/// multi-tenant cache (see SyncEngine.swift). Production talks to
/// Supabase/PostgREST; tests substitute an in-memory fake, with no network
/// involved either way.
protocol RemoteStore: Sendable {
    /// The club this store is currently scoped to, or `nil` if the
    /// signed-in user hasn't joined/selected a club yet.
    /// `SyncEngine.syncAll()` no-ops while this is `nil`.
    var clubID: String? { get async }

    /// Rows from `table` whose `updated_at` is strictly greater than
    /// `since`, each as one raw PostgREST JSON row object (`Data`).
    /// `since == nil` means "this table has never synced" — return every
    /// row for the current club.
    func pull(table: String, since: Date?) async throws -> [Data]

    /// Pushes locally-queued rows for `table` to the remote, each already
    /// encoded as PostgREST JSON (via `PostgREST.encoder`, the same
    /// encoding `Outbox.enqueue` payloads use). Expected to upsert
    /// server-side. Throwing leaves the corresponding outbox entries queued
    /// for a later retry.
    ///
    /// This is the destination for `"insert"`/`"update"` outbox entries
    /// only — `"delete"` entries go to `delete(table:rows:)`. Routing a
    /// delete here would re-upsert the row the coach just removed and, for
    /// tables whose server trigger bumps `updated_at`, resurrect it locally
    /// on the next pull.
    func push(table: String, rows: [Data]) async throws

    /// Deletes locally-removed rows for `table` from the remote. Each
    /// element is one removed row, encoded as PostgREST JSON (the same
    /// payload the `"delete"` outbox entry stored); the store identifies
    /// the row by its primary-key columns and ignores the rest. Deleting a
    /// row that is already gone server-side is a no-op, not an error.
    /// Throwing leaves the corresponding outbox entries queued for retry.
    func delete(table: String, rows: [Data]) async throws
}
