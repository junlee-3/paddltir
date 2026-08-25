// apple/Sources/Features/Schedule/ScheduleView.swift
// The Schedule tab: an "Up next" glass hero over day-grouped upcoming
// sections, with past sessions collapsed. `+` creates a training or race-day
// session. Tapping a session pushes its detail (training vs race-day).
import SwiftUI

/// `.sheet(item:)` needs `Identifiable`; `SessionKind` (Data/Models/Enums.swift)
/// is only `Codable, Hashable, Sendable` — the raw value is a stable identity.
extension SessionKind: Identifiable { var id: String { rawValue } }

struct ScheduleView: View {
    @Environment(AppModel.self) private var app
    @State private var model: ScheduleViewModel?
    @State private var newSessionKind: SessionKind?

    var body: some View {
        NavigationStack {
            Group {
                if let model { content(model) } else { ProgressView() }
            }
            .navigationTitle("Schedule")
            .background(DS.bg)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Training session") { newSessionKind = .training }
                        Button("Race day") { newSessionKind = .raceDay }
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $newSessionKind) { kind in
                SessionFormView(kind: kind) { title, startsAt, venue, notes in
                    if kind == .training { await model?.createTraining(title: title, startsAt: startsAt, venue: venue, notes: notes) }
                    else { await model?.createRaceDay(title: title, startsAt: startsAt, venue: venue, notes: notes) }
                }
            }
            .navigationDestination(for: SessionRow.self) { session in
                if session.kind == .training { TrainingDetailView(session: session) }
                else { RaceDayDetailView(session: session) }
            }
        }
        .task {
            if model == nil { model = ScheduleViewModel(db: app.environment.db) }
            await model?.load()
        }
    }

    @ViewBuilder private func content(_ model: ScheduleViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                if let up = model.upNext { upNextHero(up, model: model) }
                ForEach(model.upcoming) { section in
                    daySection(section, header: DateFormatting.day(section.day), model: model)
                }
                if !model.past.isEmpty {
                    DisclosureGroup("Past") {
                        ForEach(model.past) { section in
                            daySection(section, header: DateFormatting.day(section.day), model: model)
                        }
                    }
                    .font(.dsSubhead).foregroundStyle(DS.ink2).padding(.top, DS.Space.m)
                }
            }
            .padding(DS.Space.l)
        }
    }

    private func upNextHero(_ session: SessionRow, model: ScheduleViewModel) -> some View {
        NavigationLink(value: session) {
            GlassContainer {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    MicroLabel("UP NEXT")
                    Text(session.title).font(.dsTitle).foregroundStyle(DS.ink)
                    HStack(spacing: DS.Space.s) {
                        if let venue = session.venue { Label(venue, systemImage: "mappin.and.ellipse").font(.dsCaption).foregroundStyle(DS.ink2) }
                        Text(DateFormatting.relative(session.startsAt)).font(.dsCaption).foregroundStyle(DS.accent)
                    }
                    if let h = model.upNextHeadcount {
                        Text("\(h.inCount) in · \(h.outCount) out · \(h.noReplyCount) no reply")
                            .font(.dsCaption).foregroundStyle(DS.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func daySection(_ section: DaySection, header: String, model: ScheduleViewModel) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            MicroLabel(header.uppercased())
            ForEach(section.sessions, id: \.id) { session in
                NavigationLink(value: session) {
                    HairlineCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title).font(.dsHeadline).foregroundStyle(DS.ink)
                                Text(session.kind == .training ? "Training" : "Race day")
                                    .font(.dsCaption).foregroundStyle(DS.ink3)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(DS.ink3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Small date helpers local to the Schedule feature.
enum DateFormatting {
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month().day())
    }
    static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }
}
