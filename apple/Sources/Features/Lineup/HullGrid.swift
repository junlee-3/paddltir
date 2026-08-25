// apple/Sources/Features/Lineup/HullGrid.swift
// The boat hull — a solid, legible grid: Drummer at the bow, `n` bench rows
// (Left seat | bench# · section | Right seat), Sweep at the stern. Occupied
// seats render with the 4a SeatTile (gender-coloured); empty seats are tappable
// slots. The currently-selected seat gets an accent ring.
import SwiftUI
import PaddltirCore

struct HullGrid: View {
    let lineup: Lineup
    let roster: Roster
    let selection: LineupViewModel.Selection?
    let onTapSeat: (Seat) -> Void

    var body: some View {
        VStack(spacing: DS.Space.xs) {
            capRow("Drummer", id: lineup.drummerId)
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
            }
            capRow("Sweep", id: lineup.sweepId)
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

    @ViewBuilder private func seatCell(_ seat: Seat) -> some View {
        let selected = selection == .seat(seat)
        Button { onTapSeat(seat) } label: {
            Group {
                if let pid = lineup.paddler(at: seat), let p = roster.byID[pid] {
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
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func capRow(_ label: String, id: PaddlerID?) -> some View {
        HStack {
            MicroLabel(label)
            Spacer()
            Text(id.flatMap { roster.byID[$0]?.name } ?? "—").font(.dsCaption).foregroundStyle(DS.ink2)
        }
        .padding(.horizontal, DS.Space.s).padding(.vertical, DS.Space.xs)
        .frame(maxWidth: .infinity)
        .background(DS.surface2, in: .rect(cornerRadius: DS.R.sm))
    }
}
