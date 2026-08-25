import Foundation
import GRDB
import Testing
@testable import Paddltir

@MainActor @Suite struct SquadViewModelTests {
    private func seed(_ appDB: AppDatabase) throws {
        try appDB.write { db in
            for (id, name, g) in [("1","Alice",RowGender.female), ("2","Bob",.male)] {
                try PaddlerRow(id: id, clubId: "c", profileId: nil, name: name, email: nil, weightKg: 70,
                               preferredSide: .left, gender: g, seatPreference: .engine, boatRole: .paddler,
                               archivedAt: nil, createdAt: Date(), updatedAt: nil).insert(db)
            }
        }
    }
    @Test func loadThenFilterNarrowsVisible() async throws {
        let appDB = try AppDatabase.inMemory()
        try seed(appDB)
        let vm = SquadViewModel(db: appDB)
        await vm.load()
        #expect(vm.all.count == 2)
        #expect(vm.visible.count == 2)
        vm.filter.gender = .female
        #expect(vm.visible.map(\.row.id) == ["1"])
    }
}
