import SwiftData
import SwiftUI

/// Deuxième page : la pile de flashcards de tous les cours dus aujourd'hui.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var allCards: [Flashcard]
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var sessionToken = UUID()

    private var dueCards: [Flashcard] {
        allCards.filter { $0.isDue() }
    }

    var body: some View {
        NavigationStack {
            Group {
                if dueCards.isEmpty {
                    emptyState
                } else {
                    StudyView(source: .allDue, isEmbedded: true)
                        .id(sessionToken)
                }
            }
            .feyScreenBackground()
            .navigationTitle("Révisions du jour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !dueCards.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            sessionToken = UUID()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(FeyColor.inkSecondary)
                        }
                        .accessibilityLabel("Redémarrer la session")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: FeySpacing.lg) {
                FeyEmptyState(
                    systemImage: "checkmark.circle.fill",
                    title: allCards.isEmpty ? "Pas encore de flashcards" : "Tout est à jour",
                    message: allCards.isEmpty
                        ? "Importez un cours puis générez vos premières cartes pour démarrer la répétition espacée."
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
