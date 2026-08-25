// Pure, UI-free squad filtering/sorting + a women/men tally. No SwiftUI, no
// GRDB — operates on already-loaded PaddlerWithErg values so it's trivially
// unit-testable.
import Foundation

enum SquadSort: String, CaseIterable, Identifiable {
    case name, weight, erg
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct SquadFilter: Equatable {
    var search = ""
    var side: SidePref?
    var gender: RowGender?
    var role: RowBoatRole?
    var linkedOnly = false
}

enum SquadQuery {
    static func apply(_ paddlers: [PaddlerWithErg], filter f: SquadFilter, sort: SquadSort) -> [PaddlerWithErg] {
        let needle = f.search.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = paddlers.filter { pw in
            let r = pw.row
            if !needle.isEmpty, !r.name.lowercased().contains(needle) { return false }
            if let s = f.side, r.preferredSide != s { return false }
            if let g = f.gender, r.gender != g { return false }
            if let role = f.role, r.boatRole != role { return false }
            if f.linkedOnly, r.profileId == nil { return false }
            return true
        }
        switch sort {
        case .name:   return filtered.sorted { $0.row.name.localizedCaseInsensitiveCompare($1.row.name) == .orderedAscending }
        case .weight: return filtered.sorted { $0.row.weightKg < $1.row.weightKg }
        case .erg:    return filtered.sorted { ($0.latestErg?.metres ?? Int.min) > ($1.latestErg?.metres ?? Int.min) }
        }
    }
}

struct GenderTally: Equatable {
    let women: Int
    let men: Int
    static func of(_ members: [PaddlerWithErg]) -> GenderTally {
        GenderTally(women: members.filter { $0.row.gender == .female }.count,
                    men: members.filter { $0.row.gender == .male }.count)
    }
}
