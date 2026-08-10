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
                VStack(alignment: .leading, spacing: FeySpacing.lg) {
                    header
                    identityCard
                    statsGrid
                    activityChart
                    friendsSection
                }
                .padding(.horizontal, FeySpacing.screen)
                .padding(.top, FeySpacing.xs)
                .padding(.bottom, FeyLayout.tabBarClearance)
            }
            .feyScreenBackground()
            .feyTabBar()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Compte local")
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.inkTertiary)

                Text("Profil")
                    .font(FeyFont.screenTitle)
                    .foregroundStyle(FeyColor.ink)
                    .tracking(FeyTracking.tight)
            }

            Spacer(minLength: FeySpacing.sm)

            FeyCircleButton(systemImage: "gearshape", accessibilityTitle: "Réglages") {
                showSettings = true
            }
        }
        .padding(.top, FeySpacing.xs)
    }

    private var identityCard: some View {
        HStack(spacing: FeySpacing.md) {
            Text("É")
                .font(FeyFont.hanken(20, weight: .semibold))
                .foregroundStyle(Color(hex: 0x47665A))
                .frame(width: 62, height: 62)
                .background(Color(hex: 0xE4ECE6), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Étudiant")
                    .font(FeyFont.pageTitle)
                    .foregroundStyle(FeyColor.ink)
                    .tracking(FeyTracking.tight)
                Text("Aucune donnée envoyée hors des appels IA")
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .feyCard(padding: FeySpacing.md, radius: FeyRadius.xl, elevated: false)
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            FeySectionHeader(title: "Vos statistiques")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: FeySpacing.sm), GridItem(.flexible(), spacing: FeySpacing.sm)],
                spacing: FeySpacing.sm
            ) {
                statTile("\(StudyStats.streak(reviewDates: reviewDates))", "jours de série")
                statTile("\(logs.count)", "révisions totales")
                statTile("\(courses.count)", "cours")
                statTile("\(cards.count)", "flashcards")
            }
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(FeyFont.display(24))
                .foregroundStyle(FeyColor.ink)
            Text(label)
                .font(FeyFont.micro)
                .foregroundStyle(FeyColor.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .feyCard(padding: FeySpacing.sm + 2, radius: FeyRadius.lg, elevated: false)
    }

    private var activityChart: some View {
        let counts = StudyStats.dailyCounts(reviewDates: reviewDates, days: 14)
        let maximum = max(counts.max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: FeySpacing.sm) {
            FeySectionHeader(title: "14 derniers jours")

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(counts.enumerated()), id: \.offset) { _, count in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(count > 0 ? FeyColor.ink : FeyColor.surfaceSunken)
                        .frame(height: max(6, CGFloat(count) / CGFloat(maximum) * 76))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 84, alignment: .bottom)
            .feyCard(padding: FeySpacing.sm + 2, radius: FeyRadius.lg, elevated: false)
        }
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            FeySectionHeader(title: "Amis")

            VStack(spacing: FeySpacing.xs) {
                Image(systemName: "person.2")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(FeyColor.inkTertiary)
                    .frame(width: 56, height: 56)
                    .background(FeyColor.surfaceMuted, in: Circle())

                Text("Révisez à plusieurs")
                    .font(FeyFont.cardTitle)
                    .foregroundStyle(FeyColor.ink)
                    .padding(.top, FeySpacing.xxs)

                Text("Ajoutez vos amis, comparez vos séries et partagez vos paquets. Cette section s'activera avec les comptes.")
                    .font(FeyFont.body)
                    .foregroundStyle(FeyColor.inkTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .feyCard(padding: FeySpacing.lg, radius: FeyRadius.xl, elevated: false)
        }
    }
}
