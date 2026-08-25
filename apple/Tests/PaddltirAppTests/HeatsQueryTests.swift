// apple/Tests/PaddltirAppTests/HeatsQueryTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct HeatsQueryTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    @Test func heatsReturnedInSortOrder() async throws {
        let db = try AppDatabase.inMemory()
        try db.write { d in
            try Heat(id: "b", raceId: "r", name: "Heat 2", sortOrder: 1, drummerId: nil, sweepId: nil, createdAt: t0, updatedAt: nil).insert(d)
            try Heat(id: "a", raceId: "r", name: "Heat 1", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: t0, updatedAt: nil).insert(d)
            try Heat(id: "c", raceId: "other", name: "X", sortOrder: 0, drummerId: nil, sweepId: nil, createdAt: t0, updatedAt: nil).insert(d)
        }
        let heats = try await LineupRepository(db: db).heats(raceId: "r")
        #expect(heats.map(\.id) == ["a", "b"])   // sort_order, only race "r"
    }
}
