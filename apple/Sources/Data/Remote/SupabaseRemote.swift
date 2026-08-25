// SupabaseRemote.swift
// RemoteStore backed by a live Supabase project via supabase-swift's
// PostgREST query builder (`.select()`/`.upsert()`) and Auth.
//
// `pull(table:since:)` issues one PostgREST SELECT per table, filtered on
// that table's "last changed" column when `since != nil`. Most tables carry
// `updated_at` (refreshed by a DB trigger — see the `set_updated_at` trigger
// in supabase/migrations/20260822000100_types_tables.sql), but three
// append-only tables — erg_tests, crew_members, heat_reserves — have no
// `updated_at` column at all, only `created_at`; filtering those on
// `updated_at` would be a PostgREST 400 ("column does not exist"). See
// `timestampColumn(for:)` below, which mirrors the same fallback
// SyncableTable.swift's `syncTimestamp` already applies client-side.
//
// PostgREST returns one JSON *array* for the whole SELECT, but `RemoteStore`
// (and SyncEngine/SyncableTable on the other end) expect `[Data]` — one raw
// row object per element, matching the shape SyncEngineTests' `FakeRemote`
// already uses. `splitRows(_:)` below re-splits the array response into
// per-row `Data` via `JSONSerialization`.
//
// `push(table:rows:)` upserts the outbox's already-PostgREST-encoded row
// payloads (see Outbox.swift / PostgREST.encoder) essentially unchanged:
// each `Data` blob is decoded into `JSONObject` (`[String: AnyJSON]`, from
// supabase-swift's Helpers module, re-exported via `import Supabase`) rather
// than into a typed Swift model, so no Date-decoding strategy is involved on
// the way back out — the wire JSON round-trips byte-for-byte in spirit.
// Upserting resolves conflicts on each table's primary key (the default
// when `onConflict` is omitted), matching this schema's composite keys.
//
// `delete(table:rows:)` handles the outbox's `"delete"` entries — never
// `push`, which would re-upsert a removed row — issuing one PostgREST
// DELETE per removed row, filtered to equality on that table's primary-key
// columns only (see `primaryKeyColumns`).
//
// `clubID` resolves the signed-in user's club from `profiles.club_id` and
// caches only a *successful*, non-nil resolution (see the property) — this
// type is an `actor` (rather than a plain struct/class) both because
// `RemoteStore` requires `Sendable` and because the cache is mutable state
// shared across concurrent callers.

import Foundation
import Supabase

actor SupabaseRemote: RemoteStore {
    private let client: SupabaseClient

    /// The resolved club id, cached once known. Only a *successful*, non-nil
    /// resolution is cached: a nil resolution (no session yet, or a profile
    /// row with no `club_id`) is deliberately NOT remembered, so the very
    /// first `sync()` that `RootView` fires before sign-in doesn't pin this
    /// to nil for the whole process and dead-end every post-sign-in sync
    /// until relaunch. Re-querying `profiles` once per foreground sync while
    /// club-less is negligible and self-heals the moment the user joins one.
    private var cachedClubID: String?

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - RemoteStore

    var clubID: String? {
        get async {
            if let cachedClubID {
                return cachedClubID
            }
            let value = await fetchClubID()
            if value != nil {
                cachedClubID = value
            }
            return value
        }
    }

    func pull(table: String, since: Date?) async throws -> [Data] {
        let column = Self.timestampColumn(for: table)
        var query = client.from(table).select()
        if let since {
            query = query.gt(column, value: since)
        }
        let response = try await query.order(column).execute()
        return try Self.splitRows(response.data)
    }

    func push(table: String, rows: [Data]) async throws {
        guard !rows.isEmpty else { return }
        let values = try rows.map { try JSONDecoder().decode(JSONObject.self, from: $0) }
        try await client.from(table).upsert(values, returning: .minimal).execute()
    }

    func delete(table: String, rows: [Data]) async throws {
        guard !rows.isEmpty else { return }
        let pkColumns = Self.primaryKeyColumns[table] ?? ["id"]
        // One DELETE per row, filtered to equality on each primary-key
        // column only (never the volatile columns in the payload). Deletes
        // are rare and few — removing a crew member, clearing a seat — so a
        // request apiece is fine and keeps composite keys unambiguous.
        for row in rows {
            guard let object = try JSONSerialization.jsonObject(with: row) as? [String: Any] else {
                continue
            }
            var query = client.from(table).delete(returning: .minimal)
            for column in pkColumns {
                query = query.eq(column, value: Self.queryString(object[column]))
            }
            try await query.execute()
        }
    }

    // MARK: - clubID

    private struct ProfileClubID: Decodable {
        let clubId: String?
    }

    /// Non-throwing by protocol contract (`RemoteStore.clubID` is `get
    /// async`, not `get async throws`): any failure — no session, network
    /// error, no matching profile row — resolves to `nil`, same as "hasn't
    /// joined a club yet". `SyncEngine.syncAll()` already no-ops on `nil`.
    private func fetchClubID() async -> String? {
        guard let userID = try? await client.auth.session.user.id else { return nil }
        do {
            let response = try await client
                .from("profiles")
                .select("club_id")
                .eq("id", value: userID)
                .maybeSingle()
                .execute()
            let profile = try PostgREST.decoder.decode(ProfileClubID?.self, from: response.data)
            return profile?.clubId
        } catch {
            return nil
        }
    }

    // MARK: - Per-table sync column (see file header)

    private static let createdAtOnlyTables: Set<String> = ["erg_tests", "crew_members", "heat_reserves"]

    private static func timestampColumn(for table: String) -> String {
        createdAtOnlyTables.contains(table) ? "created_at" : "updated_at"
    }

    // MARK: - Primary-key columns (for delete filters)

    /// Primary-key columns per table, mirroring the `primary key (...)`
    /// clauses in supabase/migrations/20260822000100_types_tables.sql. Used
    /// to build precise DELETE filters from a removed row's payload. Any
    /// table absent here falls back to a single `id` column (every
    /// single-key table in this schema keys on `id`).
    private static let primaryKeyColumns: [String: [String]] = [
        "crew_members": ["crew_id", "paddler_id"],
        "availability": ["session_id", "paddler_id"],
        "seats": ["heat_id", "bench", "side"],
        "heat_reserves": ["heat_id", "paddler_id"],
        "category_rules": ["club_id", "category", "boat_size"],
    ]

    /// Renders a JSON primary-key value as a PostgREST filter string.
    /// PostgREST compares `eq.` filters textually and casts to the column
    /// type, so a stringified id/int/enum all match correctly.
    private static func queryString(_ value: Any?) -> String {
        switch value {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        default: return ""
        }
    }

    // MARK: - Splitting the PostgREST array response

    /// `data` is the raw bytes of a PostgREST SELECT response: a JSON array
    /// of row objects (or `[]` for no matches). Splits it into one `Data`
    /// per row object, the shape `RemoteStore.pull` promises.
    private static func splitRows(_ data: Data) throws -> [Data] {
        guard !data.isEmpty else { return [] }
        guard let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return try objects.map { try JSONSerialization.data(withJSONObject: $0) }
    }
}
