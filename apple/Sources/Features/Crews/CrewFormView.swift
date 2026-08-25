// apple/Sources/Features/Crews/CrewFormView.swift
// Create a crew: name, age division, category. Hands the fields back through
// onCreate (the caller's repository does the insert), then dismisses —
// mirrors PaddlerFormView's shape (Features/Squad).
import SwiftUI

struct CrewFormView: View {
    let clubId: String
    let onCreate: (_ name: String, _ ageDivision: String, _ category: CrewCategory) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var division = "Premier"
    @State private var category: CrewCategory = .mixed
    private let divisions = ["16U", "18U", "24U", "Premier", "Senior A", "Senior B", "Senior C"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Crew name", text: $name)
                Picker("Division", selection: $division) { ForEach(divisions, id: \.self) { Text($0).tag($0) } }
                Picker("Category", selection: $category) {
                    Text("Open").tag(CrewCategory.open); Text("Women").tag(CrewCategory.women); Text("Mixed").tag(CrewCategory.mixed)
                }
            }
            .navigationTitle("New crew")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await onCreate(name.trimmingCharacters(in: .whitespaces), division, category); dismiss() } }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
