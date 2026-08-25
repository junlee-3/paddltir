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
// `clubID` resolves the signed-in user's club from `profiles.club_id`,
// queried once per instance and cached — this type is an `actor` (rather
// than a plain struct/class) both because `RemoteStore` requires `Sendable`
// and because the cache is mutable state shared across concurrent callers.

import Foundation
import Supabase

actor SupabaseRemote: RemoteStore {
    private let client: SupabaseClient

    /// `nil` = not yet resolved; `.some(nil)` = resolved, signed-in user has
    /// no club yet. Distinguishes "haven't looked" from "looked, found none"
    /// so a genuinely club-less user isn't re-queried every call.
    private var cachedClubID: String??

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
            cachedClubID = value
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
