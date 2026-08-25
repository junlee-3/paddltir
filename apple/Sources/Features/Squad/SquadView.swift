// apple/Sources/Features/Squad/SquadView.swift
// Squad tab: a searchable/sortable/filterable roster over SquadViewModel.
// `+` presents PaddlerFormView to add a paddler; tapping a row pushes
// PaddlerDetailView (erg history, edit, archive).
import SwiftUI

struct SquadView: View {
    @Environment(AppModel.self) private var app
    @State private var model: SquadViewModel?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            Group { if let model { content(model) } else { ProgressView() } }
                .navigationTitle("Squad")
                .background(DS.bg)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) { Button { adding = true } label: { Image(systemName: "plus") } }
                }
                .navigationDestination(for: PaddlerWithErg.self) { pw in PaddlerDetailView(paddlerId: pw.row.id) }
                .sheet(isPresented: $adding) {
                    // Ruling E1: `db.read { ... }` returns `String?` (Club.fetchOne(db)?.id),
                    // and `try?` around a throwing call wraps that in another Optional —
                    // i.e. this is `String??`. `?? nil` flattens it to `String?`, then
                    // `?? ""` unwraps to a plain `String` for PaddlerFormView's `clubId`.
                    let clubId = ((try? app.environment.db.read { db in try Club.fetchOne(db)?.id }) ?? nil) ?? ""
                    if !clubId.isEmpty {
                        PaddlerFormView(clubId: clubId, existing: nil) { row in
                            _ = try? await SquadRepository(db: app.environment.db).upsert(row)
                            await model?.load()
                        }
                    } else {
                        VStack(spacing: DS.Space.m) {
                            Text("No club yet").font(.dsBody).foregroundStyle(DS.ink2)
                            Button("Close") { adding = false }.keyboardShortcut(.cancelAction)
                        }
                        .padding(DS.Space.l)
                    }
                }
        }
        .task {
            if model == nil { model = SquadViewModel(db: app.environment.db) }
            await model?.load()
        }
        .onChange(of: app.environment.syncGeneration) {
            Task { await model?.load() }
        }
    }

    @ViewBuilder private func content(_ model: SquadViewModel) -> some View {
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
