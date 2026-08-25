import Foundation
import GRDB
import Supabase
import Testing
@testable import Paddltir

@MainActor @Suite struct AppEnvironmentClubTests {
    @Test func clubIdFollowsTheLocalClubRow() async throws {
        let db = try AppDatabase.inMemory()
        let client = SupabaseClient(supabaseURL: URL(string: Secrets.supabaseURL)!, supabaseKey: Secrets.supabaseAnonKey)
        let env = AppEnvironment(client: client, db: db)
        let task = Task { await env.observeClub() }
        defer { task.cancel() }
        try db.write { d in try Club(id: "c1", name: "C", inviteCode: "ABCD2345", createdBy: nil, createdAt: Date(), updatedAt: nil).insert(d) }
        // Observation delivers asynchronously; poll briefly.
        for _ in 0..<50 where env.clubId != "c1" { try await Task.sleep(for: .milliseconds(40)) }
        #expect(env.clubId == "c1")
    }
}
