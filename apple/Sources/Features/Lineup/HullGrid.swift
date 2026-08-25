// apple/Sources/Features/Lineup/HullGrid.swift
// The boat hull — a solid, legible grid: Drummer at the bow, `n` bench rows
// (Left seat | bench# · section | Right seat), Sweep at the stern. Occupied
// seats render with the 4a SeatTile (gender-coloured); empty seats are tappable
// slots. The currently-selected seat gets an accent ring. Every seat accepts a
// drag-and-drop paddler id and offers a long-press context menu (occupied
// seats only) for unseat/lock/drummer/sweep.
import SwiftUI
import PaddltirCore

struct HullGrid: View {
    let lineup: Lineup
    let roster: Roster
    let selection: LineupViewModel.Selection?
    let actions: HullActions

    var body: some View {
        VStack(spacing: DS.Space.xs) {
            capRow("Drummer", id: lineup.drummerId, clear: actions.clearDrummer, setRole: actions.setDrummer)
            ForEach(lineup.boat.benchRange, id: \.self) { bench in
                HStack(spacing: DS.Space.xs) {
                    seatCell(Seat(bench: bench, side: .left))
                    VStack(spacing: 0) {
                        Text("\(bench)").font(.dsCaption.weight(.bold)).foregroundStyle(DS.ink3).monospacedDigit()
                        Text(section(bench)).font(.dsMicro).foregroundStyle(DS.ink3)
                    }
                    .frame(width: 56)
                    seatCell(Seat(bench: bench, side: .right))
                }
                .padding(.vertical, DS.Space.xs)
                .background(sectionFill(bench), in: .rect(cornerRadius: DS.R.sm))
            }
            capRow("Sweep", id: lineup.sweepId, clear: actions.clearSweep, setRole: actions.setSweep)
        }
        .padding(DS.Space.m)
        .background(DS.surface, in: .rect(cornerRadius: DS.R.card))
        .overlay(RoundedRectangle(cornerRadius: DS.R.card).stroke(DS.border))
    }

    private func section(_ bench: Int) -> String {
        switch lineup.boat.section(ofBench: bench) {
        case .stroke: "STROKE"; case .pace: "PACE"; case .engine: "ENGINE"; case .sprint: "SPRINT"
        }
    }

    /// Section bands: a subtle background per bench row so stroke/sprint read as
    /// distinct from pace/engine at a glance. Hairline borders on the hull card and
    /// seat tiles remain the primary depth cue — no shadows, no glass here.
    private func sectionFill(_ bench: Int) -> Color {
        switch lineup.boat.section(ofBench: bench) {
        case .stroke, .sprint: DS.surface2
        case .pace, .engine: DS.surface
        }
    }

    @ViewBuilder private func seatCell(_ seat: Seat) -> some View {
        let selected = selection == .seat(seat)
        let pid = lineup.paddler(at: seat)
        let base = Button { actions.tap(seat) } label: {
            cellLabel(seat: seat, pid: pid, selected: selected)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first else { return false }
            actions.drop(PaddlerID(raw), seat)
            return true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: seat, pid: pid))
        .accessibilityHint(accessibilityHint(for: seat))
        .accessibilityAddTraits(selected ? .isSelected : [])

        if let pid {
            base
                .draggable(pid.rawValue)
                .contextMenu {
                    Button("Unseat") { actions.unseat(seat) }
                    Button(lineup.isLocked(seat) ? "Unlock seat" : "Lock seat") { actions.toggleLock(seat) }
                    Button("Set as drummer") { actions.setDrummer(pid) }
                    Button("Set as sweep") { actions.setSweep(pid) }
                }
                .accessibilityAction(named: "Unseat") { actions.unseat(seat) }
                .accessibilityAction(named: lineup.isLocked(seat) ? "Unlock seat" : "Lock seat") { actions.toggleLock(seat) }
                .accessibilityAction(named: "Set as drummer") { actions.setDrummer(pid) }
                .accessibilityAction(named: "Set as sweep") { actions.setSweep(pid) }
        } else {
            base
        }
    }

    @ViewBuilder private func cellLabel(seat: Seat, pid: PaddlerID?, selected: Bool) -> some View {
        Group {
            if let pid, let p = roster.byID[pid] {
                SeatTile(name: p.name, side: seat.side == .left ? "L" : "R", weightKg: p.weightKg,
                         gender: p.gender, violatesPref: !p.side.matches(seat.side))
            } else {
                Text(seat.side == .left ? "L" : "R")
                    .font(.dsCaption).foregroundStyle(DS.ink3)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(DS.surface2, in: .rect(cornerRadius: DS.R.tile))
                    .overlay(RoundedRectangle(cornerRadius: DS.R.tile).stroke(DS.border, style: .init(dash: [3])))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: DS.R.tile).stroke(DS.accent, lineWidth: selected ? 2 : 0))
        .overlay(alignment: .topTrailing) {
            if lineup.isLocked(seat) {
                Image(systemName: "lock.fill")
                    .font(.dsMicro)
                    .foregroundStyle(DS.ink3)
                    .padding(DS.Space.xs)
            }
        }
    }

    /// H9: the occupant description is owned by `SeatTile`; this only adds the
    /// "Bench N left/right" prefix (occupied) or the empty-seat sentence.
    private func accessibilityLabel(for seat: Seat, pid: PaddlerID?) -> String {
        let sideWord = seat.side == .left ? "left" : "right"
        guard let pid, let p = roster.byID[pid] else {
            return "Bench \(seat.bench) \(sideWord), empty"
        }
        let sideLetter = seat.side == .left ? "L" : "R"
        let description = SeatTile.accessibilityDescription(
            name: p.name, gender: p.gender, side: sideLetter, weightKg: p.weightKg, violatesPref: !p.side.matches(seat.side))
        return "Bench \(seat.bench) \(sideWord), \(description)"
    }

    /// H9(c): the hint depends on what (if anything) is selected relative to this cell.
    /// F6: a locked seat always reads as locked — it can't be a tap/drag/swap target,
    /// so no other hint (deselect, swap, move-here) ever applies to it.
    private func accessibilityHint(for seat: Seat) -> String {
        guard !lineup.isLocked(seat) else { return "Locked — unlock to change" }
        guard let selection else { return "Double-tap to select" }
        if case .seat(let s) = selection, s == seat { return "Double-tap to deselect" }
        if let occupant = lineup.paddler(at: seat), let p = roster.byID[occupant] {
            return "Double-tap to swap with \(p.name)"
        }
        if let name = selectedPaddlerName(selection) {
            return "Double-tap to move \(name) here"
        }
        return "Double-tap to select"
    }

    private func selectedPaddlerName(_ selection: LineupViewModel.Selection) -> String? {
        switch selection {
        case .reserve(let id): return roster.byID[id]?.name
        case .seat(let s): return lineup.paddler(at: s).flatMap { roster.byID[$0]?.name }
        }
    }

    /// Drummer/Sweep row. F4: a drop here calls `setRole` with the dropped id
    /// (validated in the VM, same as every other drop); an occupied row offers a
    /// single "Clear <role>" action (context menu + matching accessibility
    /// action) — clearing and "move to reserves" are the same outcome, so there's
    /// only the one button.
    @ViewBuilder private func capRow(_ label: String, id: PaddlerID?, clear: @escaping () -> Void, setRole: @escaping (PaddlerID) -> Void) -> some View {
        let name = id.flatMap { roster.byID[$0]?.name }
        let base = HStack {
            MicroLabel(label)
            Spacer()
            Text(name ?? "—").font(.dsCaption).foregroundStyle(DS.ink2)
        }
        .padding(.horizontal, DS.Space.s).padding(.vertical, DS.Space.xs)
        .frame(maxWidth: .infinity)
        .background(DS.surface2, in: .rect(cornerRadius: DS.R.sm))
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first else { return false }
            setRole(PaddlerID(raw))
            return true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name.map { "\(label), \($0)" } ?? "\(label), empty")

        if id != nil {
            let clearTitle = "Clear \(label.lowercased())"
            base
                .contextMenu { Button(clearTitle) { clear() } }
                .accessibilityAction(named: clearTitle) { clear() }
        } else {
            base
        }
    }
}
