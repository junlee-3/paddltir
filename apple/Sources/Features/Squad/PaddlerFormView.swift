// apple/Sources/Features/Squad/PaddlerFormView.swift
// Create or edit a paddler. Hands a fully-formed PaddlerRow back through
// onSave (the caller's repository does the upsert), then dismisses.
import SwiftUI

struct PaddlerFormView: View {
    let clubId: String
    let existing: PaddlerRow?
    let onSave: (PaddlerRow) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var weight: String
    @State private var side: SidePref
    @State private var gender: RowGender
    @State private var seat: SeatPref
    @State private var role: RowBoatRole
    @State private var email: String

    init(clubId: String, existing: PaddlerRow?, onSave: @escaping (PaddlerRow) async -> Void) {
        self.clubId = clubId; self.existing = existing; self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _weight = State(initialValue: existing.map { String($0.weightKg) } ?? "")
        _side = State(initialValue: existing?.preferredSide ?? .either)
        _gender = State(initialValue: existing?.gender ?? .female)
        _seat = State(initialValue: existing?.seatPreference ?? .none)
        _role = State(initialValue: existing?.boatRole ?? .paddler)
        _email = State(initialValue: existing?.email ?? "")
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && Double(weight) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Name", text: $name); TextField("Weight (kg)", text: $weight)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                } header: { MicroLabel("PADDLER") }
                Section {
                    Picker("Side", selection: $side) { Text("Left").tag(SidePref.left); Text("Right").tag(SidePref.right); Text("Either").tag(SidePref.either) }
                    Picker("Gender", selection: $gender) { Text("Female").tag(RowGender.female); Text("Male").tag(RowGender.male) }
                    Picker("Seat", selection: $seat) { ForEach([SeatPref.stroke,.pace,.engine,.sprint,.none], id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                    Picker("Role", selection: $role) { ForEach([RowBoatRole.paddler,.drummer,.sweep], id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                }
                Section { TextField("Email (for invite)", text: $email)
                    #if os(iOS)
                    .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                    #endif
                } header: { MicroLabel("LINK") }
            }
            .navigationTitle(existing == nil ? "New paddler" : "Edit paddler")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await onSave(makeRow()); dismiss() } }.disabled(!canSave)
                }
            }
        }
    }

    private func makeRow() -> PaddlerRow {
        PaddlerRow(id: existing?.id ?? UUID().uuidString, clubId: clubId,
                   profileId: existing?.profileId, name: name.trimmingCharacters(in: .whitespaces),
                   email: email.isEmpty ? nil : email.lowercased(), weightKg: Double(weight) ?? 0,
                   preferredSide: side, gender: gender, seatPreference: seat, boatRole: role,
                   archivedAt: existing?.archivedAt, createdAt: existing?.createdAt ?? Date(),
                   updatedAt: Date())
    }
}
