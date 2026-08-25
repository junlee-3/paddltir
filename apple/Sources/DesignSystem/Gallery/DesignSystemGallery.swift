import SwiftUI
import PaddltirCore

/// One scrollable screen exercising every design-system primitive and domain component
/// against `DS.bg`, so a single screenshot validates the whole system renders. DEBUG-only
/// "Design" tab in `RootView`.
struct DesignSystemGallery: View {
    @State private var heatSelection = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                header
                colorSection
                typeSection
                buttonSection
                cardSection
                glassSection
                seatSection
                telemetrySection
                heatAndRingSection
                pillSection
                statusBannerSection
            }
            .padding(DS.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DS.bg.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("Design System")
                .font(.dsLargeTitle)
                .tracking(-0.2)
                .foregroundStyle(DS.ink)
            Text("Every token and component, in one place.")
                .font(.dsBody)
                .foregroundStyle(DS.ink2)
        }
    }

    // MARK: - Colours

    private static let swatches: [(name: String, color: Color)] = [
        ("bg", DS.bg), ("surface", DS.surface), ("surface2", DS.surface2),
        ("ink", DS.ink), ("ink2", DS.ink2), ("ink3", DS.ink3),
        ("border", DS.border), ("border2", DS.border2),
        ("primary", DS.primary), ("onPrimary", DS.onPrimary), ("accent", DS.accent),
        ("good", DS.good), ("danger", DS.danger),
        ("maleFill", DS.maleFill), ("maleBorder", DS.maleBorder),
        ("femaleFill", DS.femaleFill), ("femaleBorder", DS.femaleBorder),
    ]

    private var colorSection: some View {
        section("Colours") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: DS.Space.s)], spacing: DS.Space.m) {
                ForEach(Self.swatches, id: \.name) { swatch in
                    VStack(spacing: DS.Space.xs) {
                        RoundedRectangle(cornerRadius: DS.R.sm)
                            .fill(swatch.color)
                            .overlay(RoundedRectangle(cornerRadius: DS.R.sm).stroke(DS.border))
                            .frame(width: 44, height: 44)
                        Text(swatch.name)
                            .font(.dsCaption)
                            .foregroundStyle(DS.ink2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
    }

    // MARK: - Type scale

    private var typeSection: some View {
        section("Type scale") {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                typeRow("largeTitle", .dsLargeTitle)
                typeRow("title", .dsTitle)
                typeRow("headline", .dsHeadline)
                typeRow("body", .dsBody)
                typeRow("callout", .dsCallout)
                typeRow("subhead", .dsSubhead)
                typeRow("footnote", .dsFootnote)
                typeRow("caption", .dsCaption)
                typeRow("micro", .dsMicro)
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.m) {
                    Text("number")
                        .font(.dsCaption)
                        .foregroundStyle(DS.ink3)
                        .frame(width: 84, alignment: .leading)
                    Text("042")
                        .font(.dsNumber(22))
                        .monospacedDigit()
                        .foregroundStyle(DS.ink)
                }
            }
        }
    }

    @ViewBuilder private func typeRow(_ label: String, _ font: Font) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.m) {
            Text(label)
                .font(.dsCaption)
                .foregroundStyle(DS.ink3)
                .frame(width: 84, alignment: .leading)
            Text("Paddltir Aa 042")
                .font(font)
                .foregroundStyle(DS.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        section("Buttons") {
            VStack(spacing: DS.Space.s) {
                PrimaryButton("Save lineup") {}
                SecondaryButton("Cancel") {}
            }
        }
    }

    // MARK: - Card

    private var cardSection: some View {
        section("Card") {
            HairlineCard {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    MicroLabel("Session")
                    Text("Saturday squad paddle").font(.dsHeadline).foregroundStyle(DS.ink)
                    Text("06:30 — Boat shed").font(.dsFootnote).foregroundStyle(DS.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Glass

    private var glassSection: some View {
        section("Glass") {
            ZStack {
                LinearGradient(
                    colors: [DS.accent, DS.primary, DS.good],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: 132)
                .clipShape(RoundedRectangle(cornerRadius: DS.R.card))

                VStack(spacing: DS.Space.m) {
                    GlassBar {
                        HStack(spacing: DS.Space.s) {
                            Image(systemName: "wind").foregroundStyle(DS.ink)
                            Text("Glass bar").font(.dsCallout).foregroundStyle(DS.ink)
                        }
                    }
                    GlassContainer {
                        Text("Glass container").font(.dsCaption).foregroundStyle(DS.ink)
                    }
                }
            }
        }
    }

    // MARK: - Seat tiles (mini hull)

    private var seatSection: some View {
        section("Seat tiles") {
            VStack(spacing: DS.Space.s) {
                seatRow(left: ("Ana", "L", 58, .female, false, false),
                        right: ("Beth", "R", 66, .female, false, false))
                seatRow(left: ("Cody", "L", 92, .male, false, false),
                        right: ("Dev", "R", 78, .male, false, false))
                seatRow(left: ("Eli", "L", 88, .male, true, false),
                        right: ("Fay", "R", 60, .female, false, true))
            }
        }
    }

    private typealias TileSpec = (name: String, side: String, weightKg: Double, gender: Gender, violatesPref: Bool, lifted: Bool)

    @ViewBuilder private func seatRow(left: TileSpec, right: TileSpec) -> some View {
        HStack(spacing: DS.Space.s) {
            SeatTile(name: left.name, side: left.side, weightKg: left.weightKg, gender: left.gender,
                     violatesPref: left.violatesPref, lifted: left.lifted)
            SeatTile(name: right.name, side: right.side, weightKg: right.weightKg, gender: right.gender,
                     violatesPref: right.violatesPref, lifted: right.lifted)
        }
    }

    // MARK: - Telemetry (real Metrics via Scoring.evaluate)

    private static let sampleBoat = Boat.standard
    private static let sampleLineup: Lineup = {
        var lineup = Lineup(boat: sampleBoat)
        lineup.place(PaddlerID("ana"), at: Seat(bench: 1, side: .left))
        lineup.place(PaddlerID("beth"), at: Seat(bench: 1, side: .right))
        lineup.place(PaddlerID("cody"), at: Seat(bench: 5, side: .left))
        lineup.place(PaddlerID("dev"), at: Seat(bench: 5, side: .right))
        lineup.place(PaddlerID("eli"), at: Seat(bench: 9, side: .left))
        lineup.place(PaddlerID("fay"), at: Seat(bench: 9, side: .right))
        return lineup
    }()
    private static let sampleRoster = Roster([
        Paddler(id: PaddlerID("ana"), name: "Ana", weightKg: 58, ergM: 480, side: .left, gender: .female, seatPref: .stroke, role: .paddler),
        Paddler(id: PaddlerID("beth"), name: "Beth", weightKg: 66, ergM: 500, side: .right, gender: .female, seatPref: .none, role: .paddler),
        Paddler(id: PaddlerID("cody"), name: "Cody", weightKg: 92, ergM: 560, side: .left, gender: .male, seatPref: .none, role: .paddler),
        Paddler(id: PaddlerID("dev"), name: "Dev", weightKg: 78, ergM: 540, side: .either, gender: .male, seatPref: .none, role: .paddler),
        Paddler(id: PaddlerID("eli"), name: "Eli", weightKg: 88, ergM: 520, side: .right, gender: .male, seatPref: .none, role: .paddler),
        Paddler(id: PaddlerID("fay"), name: "Fay", weightKg: 60, ergM: 470, side: .left, gender: .female, seatPref: .none, role: .paddler),
    ])
    private static let sampleMetrics = Scoring.evaluate(sampleLineup, roster: sampleRoster)
    /// Illustrative normalised weight balance for `BalanceBeam` — left-heavy, matching the
    /// weight warning shown in the grid above.
    private static let sampleImbalance: Double = -0.35

    private var telemetrySection: some View {
        section("Telemetry") {
            HairlineCard {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    GenderBadge(metrics: Self.sampleMetrics)
                    TelemetryGrid(metrics: Self.sampleMetrics, boat: Self.sampleBoat)
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        MicroLabel("Balance")
                        BalanceBeam(imbalance: Self.sampleImbalance, label: "Weight balance")
                    }
                }
            }
        }
    }

    // MARK: - Heat switcher + availability ring

    private var heatAndRingSection: some View {
        section("Heat switcher & availability") {
            HStack(spacing: DS.Space.l) {
                HeatSwitcher(names: ["Heat 1", "Heat 2", "Heat 3"], selection: $heatSelection)
                Spacer()
                AvailabilityRing(count: 14, total: 20)
            }
        }
    }

    // MARK: - Pills & labels

    private var pillSection: some View {
        section("Pills & labels") {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                HStack(spacing: DS.Space.s) {
                    Pill("Stroke")
                    Pill("Confirmed", tint: DS.good.opacity(0.18), foreground: DS.good)
                    Pill("Warning", tint: DS.danger.opacity(0.18), foreground: DS.danger)
                    Pill("Accent", tint: DS.accent.opacity(0.15))
                }
                MicroLabel("Micro label sample")
            }
        }
    }

    // MARK: - Status banner

    private var statusBannerSection: some View {
        section("Status banner") {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                StatusBanner("Couldn't sync — showing saved data.", actionTitle: "Retry") {}
                StatusBanner("Couldn't save that change.")
            }
        }
    }

    // MARK: - Section wrapper

    @ViewBuilder private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            MicroLabel(title)
            content()
        }
    }
}
