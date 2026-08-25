// apple/Tests/PaddltirAppTests/ScheduleViewModelTests.swift
import Foundation
import GRDB
import Testing
@testable import Paddltir

@MainActor @Suite struct ScheduleViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func seed(_ appDB: AppDatabase) throws {
        try appDB.write { db in
            try Club(id: "club-1", name: "C", inviteCode: "ABCD2345", createdBy: nil, createdAt: now, updatedAt: nil).insert(db)
            try SessionRow(id: "past", clubId: "club-1", kind: .training, title: "Past", startsAt: now.addingTimeInterval(-86_400), venue: nil, notes: nil, createdAt: now, updatedAt: nil).insert(db)
            try SessionRow(id: "soon", clubId: "club-1", kind: .training, title: "Soon", startsAt: now.addingTimeInterval(3600), venue: nil, notes: nil, createdAt: now, updatedAt: nil).insert(db)
        }
    }

    @Test func loadComposesGroupingsAndClub() async throws {
        let appDB = try AppDatabase.inMemory()
        try seed(appDB)
        let vm = ScheduleViewModel(db: appDB, now: { self.now })
        await vm.load()
        #expect(vm.clubId == "club-1")
        #expect(vm.upNext?.id == "soon")
        #expect(vm.upcoming.flatMap(\.sessions).map(\.id) == ["soon"])
        #expect(vm.past.flatMap(\.sessions).map(\.id) == ["past"])
    }

    @Test func createTrainingWritesThenReloads() async throws {
        let appDB = try AppDatabase.inMemory()
        try seed(appDB)
        let vm = ScheduleViewModel(db: appDB, now: { self.now })
        await vm.load()
        await vm.createTraining(title: "New paddle", startsAt: now.addingTimeInterval(7200), venue: "Bay", notes: nil)
        #expect(vm.upcoming.flatMap(\.sessions).contains { $0.title == "New paddle" })
    }
}
