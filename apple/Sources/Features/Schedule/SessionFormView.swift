// apple/Sources/Features/Schedule/SessionFormView.swift
// Modal form to create a training or race-day session. Presented from the
// Schedule tab's `+` menu; hands the entered fields back through `onCreate`
// (the caller's ScheduleViewModel does the write), then dismisses.
import SwiftUI

struct SessionFormView: View {
    let kind: SessionKind
    let onCreate: (_ title: String, _ startsAt: Date, _ venue: String?, _ notes: String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startsAt = Date()
    @State private var venue = ""
    @State private var notes = ""
    @State private var isSaving = false

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(kind == .training ? "Tuesday paddle" : "Regatta day", text: $title)
                    DatePicker("Starts", selection: $startsAt)
                    TextField("Venue", text: $venue)
                } header: { MicroLabel(kind == .training ? "TRAINING SESSION" : "RACE DAY") }
                Section { TextField("Notes", text: $notes, axis: .vertical) } header: { MicroLabel("NOTES") }
            }
            .navigationTitle(kind == .training ? "New training" : "New race day")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            isSaving = true
                            await onCreate(title.trimmingCharacters(in: .whitespaces), startsAt,
                                           venue.isEmpty ? nil : venue, notes.isEmpty ? nil : notes)
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
