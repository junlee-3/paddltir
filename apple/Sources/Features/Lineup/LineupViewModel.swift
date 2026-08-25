// LineupViewModel.swift
// Orchestrates the lineup editor over PaddltirCore. Holds the live `Lineup`
// value, a tap `selection`, and an undo stack; every seat mutation goes
// through Lineup.place/.swap/.remove (which keep assignments canonical). No
// lineup logic lives here — balance/auto-fill/suggest are added in the next
// task and all delegate to PaddltirCore.
import Foundation
import GRDB
import PaddltirCore

@MainActor @Observable
final class LineupViewModel {
    enum Selection: Equatable { case reserve(PaddlerID); case seat(Seat) }

    private(set) var request: PlacementRequest?
    private(set) var lineup: Lineup?
    private(set) var heat: Heat?
    var selection: Selection?
    private(set) var canUndo = false
    private(set) var isSaving = false

    private let db: AppDatabase
    private let repo: LineupRepository
    private var undoStack: [Lineup] = []
    private var original: Lineup?   // reference for the `moves` metric

    init(db: AppDatabase) { self.db = db; self.repo = LineupRepository(db: db) }

    var roster: Roster? { request?.roster }
    var boat: Boat? { request?.boat }

    func load(heatId: String) async {
        guard let req = try? await repo.placementRequest(heatId: heatId) else { return }
        let h = (try? await repo.heat(id: heatId))?.heat
        request = req
        heat = h
        lineup = req.current ?? Lineup(boat: req.boat, drummerId: req.drummerId, sweepId: req.sweepId)
        original = lineup
        undoStack = []; canUndo = false; selection = nil
        #if DEBUG
        if ProcessInfo.processInfo.environment["PADDLTIR_DEBUG_AUTOFILL"] == "1" { autoFill() }
        #endif
    }

    /// Candidates not seated / drummer / sweep, strongest erg first.
    var reserves: [PaddlerID] {
        guard let request, let lineup, let roster else { return [] }
        var used = lineup.seatedIDs
        if let d = lineup.drummerId { used.insert(d) }
        if let s = lineup.sweepId { used.insert(s) }
        return request.candidates.filter { !used.contains($0) }
            .sorted { (roster.byID[$0]?.ergM ?? 0) > (roster.byID[$1]?.ergM ?? 0) }
    }

    func tapSeat(_ seat: Seat) {
        guard lineup != nil else { return }
        switch selection {
        case .reserve(let id):
            mutate { $0.place(id, at: seat) }; selection = nil
        case .seat(let s):
            if s == seat { selection = nil }
            else if lineup?.paddler(at: s) == nil && lineup?.paddler(at: seat) == nil { selection = nil }  // both empty → no-op
            else { mutate { $0.swap(s, seat) }; selection = nil }
        case nil:
            selection = .seat(seat)   // pick a source (occupied or empty) to swap/fill
        }
    }

    func tapReserve(_ id: PaddlerID) {
        guard lineup != nil else { return }
        if case .seat(let s) = selection { mutate { $0.place(id, at: s) }; selection = nil }
        else { selection = (selection == .reserve(id)) ? nil : .reserve(id) }
    }

    func unseat(_ seat: Seat) { mutate { $0.remove(at: seat) }; selection = nil }

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        lineup = prev; canUndo = !undoStack.isEmpty; selection = nil
    }

    /// Applies a mutation to `lineup`, snapshotting the prior value for undo.
    func mutate(_ change: (inout Lineup) -> Void) {
        guard var l = lineup else { return }
        undoStack.append(l); canUndo = true
        change(&l); lineup = l
    }

    func save() async {
        guard let lineup, let heat else { return }
        isSaving = true; defer { isSaving = false }
        let seats = lineup.assignments.map { a in
            SeatRow(heatId: heat.id, bench: a.bench, side: a.side == .left ? .left : .right,
                    paddlerId: a.paddlerId.rawValue, locked: a.locked, updatedAt: Date())
        }
        try? await repo.saveSeats(heatId: heat.id, seats: seats)
        try? await repo.saveHeat(heatId: heat.id, name: heat.name,
                                 drummerId: lineup.drummerId?.rawValue, sweepId: lineup.sweepId?.rawValue)
    }

    var metrics: Metrics? {
        guard let lineup, let roster else { return nil }
        return Scoring.evaluate(lineup, roster: roster, reference: original)
    }

    /// Weight list for the balance beam: right-heavy positive, clamped to ±1.
    var beamImbalance: Double {
        guard let m = metrics else { return 0 }
        let half = max(1, m.totalWeight / 2)
        return max(-1, min(1, (m.weightRight - m.weightLeft) / half))
    }

    func autoFill() {
        guard let request, let lineup else { return }
        let req = PlacementRequest(boat: request.boat, roster: request.roster, candidates: request.candidates,
                                   drummerId: lineup.drummerId, sweepId: lineup.sweepId,
                                   locked: lineup.assignments.filter(\.locked), rule: request.rule, current: lineup)
        let result = Greedy.autoFill(req)
        mutate { $0 = result.lineup }
    }

    func suggestions() -> [SwapSuggestion] {
        guard let lineup, let roster else { return [] }
        return Suggestions.swaps(in: lineup, roster: roster, reference: original, limit: 3)
    }

    func apply(_ suggestion: SwapSuggestion) {
        mutate { $0.swap(suggestion.a, suggestion.b) }
    }

    #if DEBUG
    /// Test hook: inject a request + heat without a live DB round-trip.
    func _injectForTest(request: PlacementRequest, heat: Heat) {
        self.request = request; self.heat = heat
        self.lineup = request.current ?? Lineup(boat: request.boat)
        self.original = self.lineup
    }
    #endif
}
