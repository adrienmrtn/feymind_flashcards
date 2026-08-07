import SwiftData
import SwiftUI

/// Deuxième page : la pile de flashcards de tous les cours dus aujourd'hui.
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
                    StudyView(source: .allDue, isEmbedded: true)
                        .id(sessionToken)
                } else {
                    emptyState
                }
            }
            .feyScreenBackground()
            .navigationTitle("Révisions du jour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: restart) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(FeyColor.inkSecondary)
                    }
                    .accessibilityLabel("Relancer la session")
                }
            }
            .onAppear {
                if !isSessionActive { isSessionActive = !dueCards.isEmpty }
            }
        }
    }

    private func restart() {
        isSessionActive = !dueCards.isEmpty
        sessionToken = UUID()
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: FeySpacing.lg) {
                FeyEmptyState(
                    systemImage: "checkmark.circle.fill",
                    title: allCards.isEmpty ? "Pas encore de flashcards" : "Tout est à jour",
                    message: allCards.isEmpty
                        ? "Importez un cours pour créer vos premières flashcards et démarrer la répétition espacée."
                        : "Aucune carte n'arrive à échéance. Vous pouvez réviser en avance depuis un cours."
                )
                .padding(.top, FeySpacing.xl)

                if !nextDueSummary.isEmpty {
                    VStack(alignment: .leading, spacing: FeySpacing.sm) {
                        FeySectionHeader(title: "Prochaines échéances")
                        ForEach(nextDueSummary, id: \.course.id) { entry in
                            HStack(spacing: FeySpacing.sm) {
                                Text(entry.course.emoji)
                                    .font(.system(size: 18))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Color(hexString: entry.course.accentHex).opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous)
                                    )

                                VStack(alignment: .leading, spacing: 1) {
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
                            .feyCard(padding: FeySpacing.sm, radius: FeyRadius.md, elevated: false)
                        }
                    }
                    .padding(.horizontal, FeySpacing.screen)
                }
            }
            .padding(.bottom, FeySpacing.xl)
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
