// apple/Sources/Features/Lineup/HullActions.swift
// The hull's outbound actions, bundled so HullGrid's init stays readable.
import PaddltirCore

struct HullActions {
    var tap: (Seat) -> Void
    var drop: (PaddlerID, Seat) -> Void
    var unseat: (Seat) -> Void
    var toggleLock: (Seat) -> Void
    var setDrummer: (PaddlerID) -> Void
    var setSweep: (PaddlerID) -> Void
    var clearDrummer: () -> Void
    var clearSweep: () -> Void
}
