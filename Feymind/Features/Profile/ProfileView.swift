import SwiftData
import SwiftUI

/// Cinquième page : profil, amis et réglages.
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
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(FeyColor.inkSecondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var identityCard: some View {
        HStack(spacing: FeySpacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FeyColor.accent, FeyColor.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 62, height: 62)
                Image(systemName: "person.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Étudiant")
                    .font(FeyFont.sectionTitle)
                    .foregroundStyle(FeyColor.ink)
                Text("Compte local, aucune donnée envoyée")
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.inkTertiary)
                FeyChip(text: "Connexion bientôt", systemImage: "lock.fill", tint: FeyColor.accent)
                    .padding(.top, 2)
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
                statTile("\(StudyStats.streak(reviewDates: reviewDates))", "jours de série", "flame.fill", FeyColor.amber)
                statTile("\(logs.count)", "révisions totales", "checkmark.circle.fill", FeyColor.mint)
                statTile("\(courses.count)", "cours", "book.fill", FeyColor.accent)
                statTile("\(cards.count)", "flashcards", "rectangle.on.rectangle", FeyColor.sky)
            }
        }
    }

    private func statTile(_ value: String, _ label: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
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
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(count > 0 ? FeyColor.accent.opacity(0.85) : FeyColor.surfaceSunken)
                            .frame(height: max(6, CGFloat(count) / CGFloat(maximum) * 76))
                    }
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

            VStack(spacing: FeySpacing.sm) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(FeyColor.accent)

                Text("Révisez à plusieurs")
                    .font(FeyFont.cardTitle)
                    .foregroundStyle(FeyColor.ink)

                Text("Ajoutez vos amis, comparez vos séries et partagez vos paquets. Cette section s'activera avec les comptes.")
                    .font(FeyFont.body)
                    .foregroundStyle(FeyColor.inkTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(FeySpacing.lg)
            .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.xl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FeyRadius.xl, style: .continuous)
                    .strokeBorder(FeyColor.stroke, lineWidth: 1)
            }
        }
    }
}
