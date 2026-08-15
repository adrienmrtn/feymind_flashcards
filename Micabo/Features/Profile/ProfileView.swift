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
                VStack(alignment: .leading, spacing: 18) {
                    header
                    identityCard
                    statsGrid
                    activityChart
                    friendsSection
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, MicaboSpacing.xl)
            }
            .micaboScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .micaboTabBarClearance()
            .reportsNavigationDepth(for: .profile, depth: 0)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Profil")
                .font(MicaboFont.hanken(26, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.4)

            Spacer(minLength: MicaboSpacing.sm)

            MicaboCircleButton(systemImage: "gearshape", accessibilityTitle: "Réglages") {
                showSettings = true
            }
        }
        .padding(.top, MicaboSpacing.xs)
    }

    private var identityCard: some View {
        HStack(spacing: 14) {
            Text("É")
                .font(MicaboFont.hanken(20, weight: .semibold))
                .foregroundStyle(Color(hex: 0x47665A))
                .frame(width: 54, height: 54)
                .background(Color(hex: 0xE4ECE6), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Étudiant")
                    .font(MicaboFont.hanken(17, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                Text("Aucune donnée envoyée hors des appels IA")
                    .font(MicaboFont.hanken(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            statTile("\(StudyStats.streak(reviewDates: reviewDates))", "jours de série")
            statTile(formattedCount(logs.count), "révisions")
            statTile("\(courses.count)", "cours")
            statTile("\(cards.count)", "flashcards")
        }
    }

    private func formattedCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(MicaboFont.hanken(22, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.3)
            Text(label)
                .font(MicaboFont.hanken(11, weight: .medium))
                .foregroundStyle(Color(hex: 0x9A958A))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    private var activityChart: some View {
        let counts = StudyStats.dailyCounts(reviewDates: reviewDates, days: 14)
        let maximum = max(counts.max() ?? 1, 1)
        let total = counts.reduce(0, +)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("14 derniers jours")
                    .font(MicaboFont.hanken(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                Spacer()
                Text("\(total) révisions")
                    .font(MicaboFont.hanken(12, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                    let isToday = index == counts.count - 1
                    let isPeak = count == maximum && count > 0 && !isToday
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(barColor(count: count, isToday: isToday, isPeak: isPeak))
                        .frame(height: max(4, CGFloat(count) / CGFloat(maximum) * 52))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 52, alignment: .bottom)
        }
        .padding(16)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    private func barColor(count: Int, isToday: Bool, isPeak: Bool) -> Color {
        if count == 0 { return MicaboColor.surfaceSunken }
        if isToday { return MicaboColor.ink }
        if isPeak { return MicaboColor.accent }
        return MicaboColor.surfaceSunken
    }

    private var friendsSection: some View {
        HStack {
            Text("Amis")
                .font(MicaboFont.hanken(13, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
            Spacer()
            Text("Bientôt")
                .font(MicaboFont.hanken(12, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(16)
        .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(Color(hex: 0xDDD6C8))
        }
    }
}
