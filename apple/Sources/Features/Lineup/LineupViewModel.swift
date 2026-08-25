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
    private(set) var canRedo = false
    private(set) var isSaving = false
    private(set) var isLoaded = false
    private(set) var lastError: String?

    private(set) var heats: [Heat] = []
    var selectedHeatIndex = 0 { didSet { if let h = heats[safe: selectedHeatIndex], h.id != heat?.id { Task { await load(heatId: h.id) } } } }

    private let db: AppDatabase
    private let repo: LineupRepository
    private var undoStack: [Lineup] = []
    private var redoStack: [Lineup] = []
    private var original: Lineup?   // reference for the `moves` metric

    init(db: AppDatabase) { self.db = db; self.repo = LineupRepository(db: db) }

    var roster: Roster? { request?.roster }
    var boat: Boat? { request?.boat }

    /// One-shot: the editor edits a local `Lineup` value, so a live
    /// observation would clobber unsaved edits — the view re-runs this
    /// explicitly (initial `.task`, or "Try again" on the empty state).
    /// `isLoaded` means "the load finished", whether or not a placement
    /// request resolved; a nil `request`/`lineup` after that is what
    /// selects the empty state.
    func load(heatId: String) async {
        guard let req = try? await repo.placementRequest(heatId: heatId) else { isLoaded = true; return }
        let h = (try? await repo.heat(id: heatId))?.heat
        request = req
        heat = h
        lineup = req.current ?? Lineup(boat: req.boat, drummerId: req.drummerId, sweepId: req.sweepId)
        original = lineup
        undoStack = []; canUndo = false; redoStack = []; canRedo = false; selection = nil
        #if DEBUG
        if ProcessInfo.processInfo.environment["PADDLTIR_DEBUG_AUTOFILL"] == "1" { autoFill() }
        #endif
        isLoaded = true
    }

    /// Long-lived: mirrors the race's heats; creates "Heat 1" for a race with none.
    /// Auto-creates at most once per call — a stale/duplicate empty emission from the
    /// same observation can never create a second heat.
    func observeHeats(raceId: String) async {
        var didAutoCreate = false
        do {
            for try await list in repo.observeHeats(raceId: raceId).values(in: db.dbQueue) {
                if list.isEmpty {
                    guard !didAutoCreate else { continue }
                    didAutoCreate = true
                    _ = try await repo.createHeat(raceId: raceId, name: "Heat 1")
                    continue
                }
                heats = list
                if heat == nil, let first = list.first { await load(heatId: first.id) }
            }
        } catch { lastError = error.localizedDescription }
    }

    func addHeat(raceId: String) async {
        do {
            let h = try await repo.createHeat(raceId: raceId, name: "Heat \(heats.count + 1)")
            selectedHeatIndex = heats.firstIndex { $0.id == h.id } ?? heats.count
            await load(heatId: h.id)
        } catch { lastError = error.localizedDescription }
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
        guard let prev = undoStack.popLast(), let current = lineup else { return }
        redoStack.append(current); canRedo = true
        lineup = prev; canUndo = !undoStack.isEmpty; selection = nil
    }

    func redo() {
        guard let next = redoStack.popLast(), let current = lineup else { return }
        undoStack.append(current); canUndo = true
        lineup = next; canRedo = !redoStack.isEmpty; selection = nil
    }

    /// Applies a mutation to `lineup`, snapshotting the prior value for undo
    /// and clearing the redo stack (a fresh edit invalidates any redo history).
    func mutate(_ change: (inout Lineup) -> Void) {
        guard var l = lineup else { return }
        undoStack.append(l); canUndo = true
        redoStack.removeAll(); canRedo = false
        change(&l); lineup = l
    }

    /// Drag-and-drop: a reserve or a seated paddler dropped onto a seat.
    /// Seated → occupied = swap; seated → empty = move; reserve → any = place
    /// (an evicted occupant returns to the reserves). All via Lineup.
    ///
    /// H12: drops accept any `String` payload, so a drag from outside the app could
    /// carry an id that isn't in the roster — validated here, the VM's single choke
    /// point, so an unknown id is a no-op (no mutate, no undo entry, no save).
    func dragDrop(_ id: PaddlerID, onto seat: Seat) {
        guard roster?.byID[id] != nil else { return }
        guard let current = lineup else { return }
        if let from = current.seat(of: id) {
            guard from != seat else { return }
            if current.paddler(at: seat) != nil { mutate { $0.swap(from, seat) } } else { mutate { $0.place(id, at: seat) } }
        } else {
            mutate { $0.place(id, at: seat) }
        }
        selection = nil
    }

    func dropOnTray(_ id: PaddlerID) {
        guard roster?.byID[id] != nil else { return }
        guard lineup?.seat(of: id) != nil else { return }
        mutate { $0.remove(id) }; selection = nil
    }

    func toggleLock(_ seat: Seat) {
        guard let current = lineup, current.paddler(at: seat) != nil else { return }
        mutate { $0.setLocked(!current.isLocked(seat), at: seat) }
    }

    /// Drummer/sweep can't also hold a bench seat; assigning removes them from the hull.
    /// H12: same id validation as `dragDrop`/`dropOnTray` — `nil` (clearing the role) is
    /// always allowed, a non-nil id must resolve in the roster.
    func setDrummer(_ id: PaddlerID?) {
        guard id == nil || roster?.byID[id!] != nil else { return }
        mutate { l in if let id { l.remove(id); if l.sweepId == id { l.sweepId = nil } }; l.drummerId = id }
    }
    func setSweep(_ id: PaddlerID?) {
        guard id == nil || roster?.byID[id!] != nil else { return }
        mutate { l in if let id { l.remove(id); if l.drummerId == id { l.drummerId = nil } }; l.sweepId = id }
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
