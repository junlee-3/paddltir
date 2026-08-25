import Foundation
import GRDB

@MainActor @Observable
final class SquadViewModel {
    var filter = SquadFilter()
    var sort: SquadSort = .name
    private(set) var all: [PaddlerWithErg] = []

    private let squad: SquadRepository
    init(db: AppDatabase) { self.squad = SquadRepository(db: db) }

    var visible: [PaddlerWithErg] { SquadQuery.apply(all, filter: filter, sort: sort) }

    func load() async { all = (try? await squad.paddlers()) ?? [] }
}
