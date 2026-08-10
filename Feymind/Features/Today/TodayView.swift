import SwiftData
import SwiftUI

/// La pile de flashcards de tous les cours dues aujourd'hui.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var allCards: [Flashcard]
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var sessionToken = UUID()
    /// Une fois lancée, la session reste affichée même quand plus aucune carte n'est due :
    /// les cartes d'apprentissage doivent pouvoir revenir dans les vingt minutes.
    @State private var isSessionActive = false

    private var dueCards: [Flashcard] {
        allCards.filter { $0.isDue() }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSessionActive {
                    VStack(spacing: 0) {
                        header
                        StudyView(source: .allDue, isEmbedded: true)
                            .id(sessionToken)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: FeySpacing.lg) {
                            header
                            emptyState
                        }
                        .padding(.bottom, FeyLayout.tabBarClearance)
                    }
                }
            }
            .feyScreenBackground()
            .feyTabBar()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if !isSessionActive { isSessionActive = !dueCards.isEmpty }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(StudyStats.formattedDate())
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.inkTertiary)

                Text("Réviser")
                    .font(FeyFont.screenTitle)
                    .foregroundStyle(FeyColor.ink)
                    .tracking(FeyTracking.tight)
            }

            Spacer(minLength: FeySpacing.sm)

            FeyCircleButton(
                systemImage: "arrow.counterclockwise",
                size: 44,
                accessibilityTitle: "Relancer la session"
            ) {
                restart()
            }
        }
        .padding(.horizontal, FeySpacing.screen)
        .padding(.top, FeySpacing.xs)
        .padding(.bottom, FeySpacing.sm)
    }

    private func restart() {
        isSessionActive = !dueCards.isEmpty
        sessionToken = UUID()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: FeySpacing.lg) {
            FeyEmptyState(
                systemImage: allCards.isEmpty ? "rectangle.on.rectangle.angled" : "checkmark",
                title: allCards.isEmpty ? "Pas encore de flashcards" : "Tout est à jour",
                message: allCards.isEmpty
                    ? "Importez un cours pour créer vos premières flashcards et démarrer la répétition espacée."
                    : "Aucune carte n'arrive à échéance. Vous pouvez réviser en avance depuis un cours."
            )

            if !nextDueSummary.isEmpty {
                VStack(alignment: .leading, spacing: FeySpacing.sm) {
                    FeySectionHeader(title: "Prochaines échéances")

                    ForEach(nextDueSummary, id: \.course.id) { entry in
                        HStack(spacing: FeySpacing.sm) {
                            CourseCover(course: entry.course, emojiSize: 18)
                                .frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.course.title)
                                    .font(FeyFont.bodyEmphasis)
                                    .foregroundStyle(FeyColor.ink)
                                    .lineLimit(1)
                                Text(entry.label)
                                    .font(FeyFont.micro)
                                    .foregroundStyle(FeyColor.inkTertiary)
                            }

                            Spacer(minLength: 0)
                        }
                        .feyCard(padding: FeySpacing.sm, radius: FeyRadius.lg, elevated: false)
                    }
                }
                .padding(.horizontal, FeySpacing.screen)
            }
        }
    }

    private var nextDueSummary: [(course: Course, label: String)] {
        courses.compactMap { course in
            guard let next = course.cards.filter({ !$0.isSuspended }).map(\.dueDate).min() else { return nil }
            let delay = next.timeIntervalSinceNow
            guard delay > 0 else { return nil }
            return (course, "Dans " + SM2Scheduler.format(delay: delay))
        }
        .prefix(4)
        .map { $0 }
    }
}
