import SwiftData
import SwiftUI

/// Profil, statistiques et réglages.
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var courses: [Course]
    @Query private var cards: [Flashcard]
    @Query private var logs: [ReviewLog]

    @State private var showSettings = false

    private var reviewDates: [Date] { logs.map(\.reviewedAt) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    header
                    identityCard
                    statsGrid
                    activityCard
                    optionsSection
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, MicaboSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .micaboTabBar()
            .reportsPaging(for: .profile, depth: 0)
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationCornerRadius(MicaboRadius.sheet)
            }
        }
    }

    private var header: some View {
        MicaboScreenHeader(title: "Profil", eyebrow: streakLabel) {
            MicaboCircleButton(systemImage: "gearshape", size: 44, accessibilityTitle: "Réglages") {
                showSettings = true
            }
        }
        .padding(.top, MicaboSpacing.xs)
    }

    private var streakLabel: String {
        let streak = StudyStats.streak(reviewDates: reviewDates)
        guard streak > 0 else { return "Aucune série en cours" }
        return "Série de \(streak) jour\(streak > 1 ? "s" : "")"
    }

    private var identityCard: some View {
        HStack(spacing: 14) {
            Text("É")
                .font(MicaboFont.hanken(21, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)
                .frame(width: 54, height: 54)
                .background(MicaboColor.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Étudiant")
                    .font(MicaboFont.hanken(17, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                Text("Tout reste sur cet appareil")
                    .font(MicaboFont.rowSubtitle)
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Statistiques")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                statTile("\(StudyStats.streak(reviewDates: reviewDates))", "jours de série")
                statTile(formattedCount(logs.count), "révisions")
                statTile("\(courses.count)", "cours")
                statTile("\(cards.count)", "flashcards")
            }
        }
    }

    private func formattedCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(MicaboFont.hanken(26, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(MicaboTracking.tight)
            Text(label)
                .font(MicaboFont.hanken(12, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 15)
        .micaboGroup(radius: MicaboRadius.md)
    }

    private var activityCard: some View {
        let counts = StudyStats.dailyCounts(reviewDates: reviewDates, days: 14)
        let maximum = max(counts.max() ?? 1, 1)
        let total = counts.reduce(0, +)

        return VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "14 derniers jours")

            VStack(alignment: .leading, spacing: 16) {
                Text("\(total) révision\(total > 1 ? "s" : "")")
                    .font(MicaboFont.hanken(20, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(MicaboTracking.tight)

                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                        let isToday = index == counts.count - 1
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(barColor(count: count, isToday: isToday))
                            .frame(height: max(4, CGFloat(count) / CGFloat(maximum) * 56))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 56, alignment: .bottom)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .micaboGroup()
        }
    }

    private func barColor(count: Int, isToday: Bool) -> Color {
        if count == 0 { return MicaboColor.surfaceMuted }
        if isToday { return MicaboColor.accent }
        return MicaboColor.accent.opacity(0.35)
    }

    private var optionsSection: some View {
        MicaboSettingsSection(
            caption: "Compte",
            rows: [
                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("⚙️"), background: MicaboColor.tilePastels[0]),
                    title: "Réglages",
                    accessory: .chevron,
                    action: { showSettings = true }
                ),
                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("👋"), background: MicaboColor.tilePastels[2]),
                    title: "Amis",
                    subtitle: "Comparer vos séries",
                    accessory: .badge("bientôt", .neutral)
                )
            ]
        )
    }
}
