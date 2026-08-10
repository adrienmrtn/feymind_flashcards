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
                .padding(.horizontal, FeySpacing.screen)
                .padding(.top, FeySpacing.xs)
                .padding(.bottom, FeySpacing.xl)
            }
            .feyScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Profil")
                .font(FeyFont.hanken(26, weight: .bold))
                .foregroundStyle(FeyColor.ink)
                .tracking(-0.4)

            Spacer(minLength: FeySpacing.sm)

            FeyCircleButton(systemImage: "gearshape", accessibilityTitle: "Réglages") {
                showSettings = true
            }
        }
        .padding(.top, FeySpacing.xs)
    }

    private var identityCard: some View {
        HStack(spacing: 14) {
            Text("É")
                .font(FeyFont.hanken(20, weight: .semibold))
                .foregroundStyle(Color(hex: 0x47665A))
                .frame(width: 54, height: 54)
                .background(Color(hex: 0xE4ECE6), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Étudiant")
                    .font(FeyFont.hanken(17, weight: .semibold))
                    .foregroundStyle(FeyColor.ink)
                Text("Aucune donnée envoyée hors des appels IA")
                    .font(FeyFont.hanken(12, weight: .regular))
                    .foregroundStyle(FeyColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.card, style: .continuous)
                .strokeBorder(FeyColor.stroke, lineWidth: 1)
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
                .font(FeyFont.hanken(22, weight: .bold))
                .foregroundStyle(FeyColor.ink)
                .tracking(-0.3)
            Text(label)
                .font(FeyFont.hanken(11, weight: .medium))
                .foregroundStyle(Color(hex: 0x9A958A))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous)
                .strokeBorder(FeyColor.stroke, lineWidth: 1)
        }
    }

    private var activityChart: some View {
        let counts = StudyStats.dailyCounts(reviewDates: reviewDates, days: 14)
        let maximum = max(counts.max() ?? 1, 1)
        let total = counts.reduce(0, +)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("14 derniers jours")
                    .font(FeyFont.hanken(13, weight: .semibold))
                    .foregroundStyle(FeyColor.ink)
                Spacer()
                Text("\(total) révisions")
                    .font(FeyFont.hanken(12, weight: .medium))
                    .foregroundStyle(FeyColor.inkTertiary)
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
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.card, style: .continuous)
                .strokeBorder(FeyColor.stroke, lineWidth: 1)
        }
    }

    private func barColor(count: Int, isToday: Bool, isPeak: Bool) -> Color {
        if count == 0 { return FeyColor.surfaceSunken }
        if isToday { return FeyColor.ink }
        if isPeak { return FeyColor.accent }
        return FeyColor.surfaceSunken
    }

    private var friendsSection: some View {
        HStack {
            Text("Amis")
                .font(FeyFont.hanken(13, weight: .semibold))
                .foregroundStyle(FeyColor.inkSecondary)
            Spacer()
            Text("Bientôt")
                .font(FeyFont.hanken(12, weight: .medium))
                .foregroundStyle(FeyColor.inkTertiary)
        }
        .padding(16)
        .background(FeyColor.surfaceMuted, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(Color(hex: 0xDDD6C8))
        }
    }
}
