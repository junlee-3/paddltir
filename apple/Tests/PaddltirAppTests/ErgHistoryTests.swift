import Foundation
import GRDB
import Testing
@testable import Paddltir

@Suite struct ErgHistoryTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func ergHistoryReturnsAllTestsOldestFirst() async throws {
        let appDB = try AppDatabase.inMemory()
        try appDB.write { db in
            try ErgTest(id: "e2", paddlerId: "p-1", testedAt: t0.addingTimeInterval(100), metres: 640, source: .coach, recordedBy: nil, createdAt: t0).insert(db)
            try ErgTest(id: "e1", paddlerId: "p-1", testedAt: t0, metres: 600, source: .coach, recordedBy: nil, createdAt: t0).insert(db)
            try ErgTest(id: "e3", paddlerId: "p-2", testedAt: t0, metres: 500, source: .coach, recordedBy: nil, createdAt: t0).insert(db)
        }
        let history = try await SquadRepository(db: appDB).ergHistory(paddlerId: "p-1")
        #expect(history.map(\.id) == ["e1", "e2"])   // oldest-first, only p-1
        #expect(history.map(\.metres) == [600, 640])
    }
}
