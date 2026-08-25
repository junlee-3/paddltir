// apple/Tests/PaddltirAppTests/CrewGenderRuleTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@MainActor @Suite struct CrewGenderRuleTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    @Test func womenOnlyCrewWithAManViolates() async throws {
        let db = try AppDatabase.inMemory()
        try db.write { d in
            try Club(id: "c1", name: "C", inviteCode: "ABCD2345", createdBy: nil, createdAt: t0, updatedAt: nil).insert(d)
            try Crew(id: "cr1", clubId: "c1", name: "W", ageDivision: "Premier", category: .women, createdAt: t0, updatedAt: nil).insert(d)
            // women category, standard boat → max_men 0
            try CategoryRule(clubId: "c1", category: .women, boatSize: .standard, minWomen: nil, maxWomen: nil, minMen: nil, maxMen: 0, updatedAt: t0).insert(d)
            try PaddlerRow(id: "m1", clubId: "c1", profileId: nil, name: "Man", email: nil, weightKg: 80, preferredSide: .left, gender: .male, seatPreference: .none, boatRole: .paddler, archivedAt: nil, createdAt: t0, updatedAt: nil).insert(d)
            try CrewMember(crewId: "cr1", paddlerId: "m1", createdAt: t0).insert(d)
        }
        let model = CrewDetailModel(crewId: "cr1", db: db)
        await model.load()
        #expect(model.ruleVerdict != nil)   // a man in a women-only crew is a violation
    }
}
