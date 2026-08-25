// apple/Sources/Features/Squad/SquadView.swift
// Squad tab: a searchable/sortable/filterable roster over SquadViewModel.
// `+` presents PaddlerFormView to add a paddler; tapping a row pushes
// PaddlerDetailView (erg history, edit, archive).
import SwiftUI

struct SquadView: View {
    @Environment(AppModel.self) private var app
    @State private var model: SquadViewModel
    @State private var adding = false

    init(db: AppDatabase) { _model = State(initialValue: SquadViewModel(db: db)) }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Squad")
                .background(DS.bg)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { adding = true } label: { Image(systemName: "plus") }
                            .disabled(app.environment.clubId == nil)
                    }
                }
                .navigationDestination(for: PaddlerWithErg.self) { pw in PaddlerDetailView(paddlerId: pw.row.id) }
                .sheet(isPresented: $adding) {
                    if let clubId = app.environment.clubId {
                        PaddlerFormView(clubId: clubId, existing: nil) { row in await model.add(row) }
                    } else {
                        VStack(spacing: DS.Space.m) {
                            Text("No club yet").font(.dsBody).foregroundStyle(DS.ink2)
                            Button("Close") { adding = false }.keyboardShortcut(.cancelAction)
                        }
                        .padding(DS.Space.l)
                    }
                }
        }
        .task { await model.observe() }
    }

    @ViewBuilder private var content: some View {
        if !model.isLoaded && model.all.isEmpty {
            ProgressView()
        } else {
            @Bindable var model = model
            List {
                Section {
                    Picker("Sort", selection: $model.sort) { ForEach(SquadSort.allCases) { Text($0.label).tag($0) } }
                        .pickerStyle(.segmented)
                    Toggle("Linked only", isOn: $model.filter.linkedOnly)
                }
                ForEach(model.visible) { pw in
                    NavigationLink(value: pw) { row(pw) }
                }
            }
            .searchable(text: $model.filter.search)
        }
    }

    private func row(_ pw: PaddlerWithErg) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(pw.row.name).font(.dsBody).foregroundStyle(DS.ink)
                Text("\(pw.row.weightKg, specifier: "%.0f") kg · \(pw.row.preferredSide.rawValue) · \(pw.row.seatPreference.rawValue)")
                    .font(.dsCaption).foregroundStyle(DS.ink3)
            }
            Spacer()
            if let m = pw.latestErg?.metres { Text("\(m) m").font(.dsCaption).foregroundStyle(DS.ink2).monospacedDigit() }
        }
    }
}
