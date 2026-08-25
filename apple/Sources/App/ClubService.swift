// ClubService.swift
// Typed wrappers over the onboarding SECURITY DEFINER RPCs (see
// supabase/migrations/20260822000200_functions.sql). Every response body is
// decoded with PostgREST.decoder via `.execute().data` (snake_case + dates);
// scalar returns via JSONSerialization(.fragmentsAllowed). Params go as
// [String: String] so the JSON keys match the SQL argument names exactly.
import Foundation
import Supabase

struct ClaimablePaddler: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
}

struct ClubService: Sendable {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    private struct ProfileClubID: Decodable { let clubId: String? }

    /// The signed-in user's club, or nil if their profile has none yet.
    /// Returns nil (not throws) when there is no session.
    func currentClubId() async throws -> String? {
        guard let userID = try? await client.auth.session.user.id else { return nil }
        let data = try await client.from("profiles")
            .select("club_id").eq("id", value: userID).single().execute().data
        return try PostgREST.decoder.decode(ProfileClubID.self, from: data).clubId
    }

    func createClub(name: String) async throws -> Club {
        let data = try await client.rpc("create_club", params: ["p_name": name]).execute().data
        return try PostgREST.decoder.decode(Club.self, from: data)
    }

    func claimablePaddlers(code: String) async throws -> [ClaimablePaddler] {
        let data = try await client.rpc("claimable_paddlers", params: ["p_code": code]).execute().data
        return try PostgREST.decoder.decode([ClaimablePaddler].self, from: data)
    }

    func joinClub(code: String, paddlerId: String?) async throws {
        var params = ["p_code": code]
        if let paddlerId { params["p_paddler_id"] = paddlerId }
        _ = try await client.rpc("join_club", params: params).execute()
    }

    func regenerateInviteCode() async throws -> String {
        let data = try await client.rpc("regenerate_invite_code").execute().data
        let scalar = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard let code = scalar as? String else {
            throw ClubServiceError.unexpectedResponse
        }
        return code
    }
}

enum ClubServiceError: Error { case unexpectedResponse }
