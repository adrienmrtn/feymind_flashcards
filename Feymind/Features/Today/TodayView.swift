import SwiftData
import SwiftUI

/// Écran « Réviser » : la file d'attente du jour, condensée en un seul chiffre,
/// puis un lancement plein écran de la session d'entraînement.
struct TodayView: View {
    @Query private var allCards: [Flashcard]
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var showStudy = false

    private var dueCards: [Flashcard] {
        allCards.filter { $0.isDue() }
    }

    private var newCount: Int {
        dueCards.filter { $0.state == .new }.count
    }

    private var learningCount: Int {
        dueCards.filter { $0.state == .learning || $0.state == .relearning }.count
    }

    private var reviewCount: Int {
        dueCards.filter { $0.state == .review }.count
    }

    private var lateCount: Int {
        learningCount + reviewCount
    }

    private var coursesWithDue: Int {
        Set(dueCards.compactMap { $0.course?.id }).count
    }

    /// Estimation grossière : environ 30 secondes par carte.
    private var estimatedMinutes: Int {
        max(1, Int((Double(dueCards.count) * 30 / 60).rounded(.up)))
    }

    var body: some View {
        NavigationStack {
            Group {
                if dueCards.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: FeySpacing.lg) {
                            header
                            emptyState
                        }
                        .padding(.bottom, FeyLayout.tabBarClearance)
                    }
                } else {
                    VStack(spacing: 0) {
                        header
                        sessionCard
                            .padding(.horizontal, FeySpacing.screen)
                            .padding(.bottom, FeyLayout.tabBarClearance)
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .feyScreenBackground()
            .feyTabBar()
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showStudy) {
            StudyView(source: .allDue)
        }
    }

    // MARK: - En-tête

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
        }
        .padding(.horizontal, FeySpacing.screen)
        .padding(.top, FeySpacing.xs)
        .padding(.bottom, FeySpacing.sm)
    }

    // MARK: - Carte de session

    private var sessionCard: some View {
        VStack(spacing: FeySpacing.lg) {
            HStack {
                Text("SESSION DU JOUR")
                    .font(FeyFont.hanken(12, weight: .medium))
                    .tracking(0.06)
                    .foregroundStyle(Color(hex: 0x8F8B82))

                Spacer()

                Text(coursesWithDue > 1 ? "\(coursesWithDue) cours" : "1 cours")
                    .font(FeyFont.hanken(12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xC9B98A))
            }

            VStack(spacing: 8) {
                Text("\(dueCards.count)")
                    .font(FeyFont.hanken(112, weight: .bold))
                    .tracking(-2)
                    .foregroundStyle(FeyColor.onInk)
                    .minimumScaleFactor(0.35)
                    .lineLimit(1)

                Text(dueCards.count > 1 ? "cartes dues aujourd'hui" : "carte due aujourd'hui")
                    .font(FeyFont.hanken(16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: FeySpacing.sm + 2) {
                progressSegments

                HStack {
                    Text(breakdownLabel)
                        .font(FeyFont.hanken(12, weight: .regular))
                        .foregroundStyle(Color(hex: 0x8F8B82))
                    Spacer()
                    Text("≈ \(estimatedMinutes) min")
                        .font(FeyFont.hanken(12, weight: .regular))
                        .foregroundStyle(Color(hex: 0x8F8B82))
                }

                Button {
                    showStudy = true
                } label: {
                    Text("Commencer la session")
                        .font(FeyFont.cardTitle)
                        .foregroundStyle(FeyColor.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FeyColor.canvas, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FeySpacing.lg + 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FeyColor.ink, in: RoundedRectangle(cornerRadius: FeyRadius.xl + 4, style: .continuous))
        .feySoftShadow(strength: 0.16)
    }

    private var breakdownLabel: String {
        var parts: [String] = []
        if lateCount > 0 { parts.append("\(lateCount) en retard") }
        if newCount > 0 { parts.append("\(newCount) nouvelle\(newCount > 1 ? "s" : "")") }
        return parts.isEmpty ? "Tout est nouveau" : parts.joined(separator: " · ")
    }

    private var progressSegments: some View {
        GeometryReader { proxy in
            let total = max(1, dueCards.count)
            let spacing: CGFloat = 6
            let usable = max(0, proxy.size.width - spacing * 2)

            HStack(spacing: spacing) {
                segment(color: Color(hex: 0xC9B98A), count: reviewCount, total: total, usable: usable)
                segment(color: FeyColor.accent, count: learningCount, total: total, usable: usable)
                segment(color: Color.white.opacity(0.3), count: newCount, total: total, usable: usable)
            }
        }
        .frame(height: 7)
    }

    @ViewBuilder
    private func segment(color: Color, count: Int, total: Int, usable: CGFloat) -> some View {
        if count > 0 {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: max(4, usable * CGFloat(count) / CGFloat(total)))
        }
    }

    // MARK: - États vides

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: FeySpacing.lg) {
            if allCards.isEmpty {
                FeyEmptyState(
                    systemImage: "rectangle.on.rectangle.angled",
                    title: "Pas encore de flashcards",
                    message: "Importez un cours pour créer vos premières flashcards et démarrer la répétition espacée."
                )
            } else {
                doneState
            }

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

    /// Fond vert doux et coche, distincts du gris neutre des autres états vides :
    /// il ne s'agit pas d'un manque, mais d'un objectif atteint.
    private var doneState: some View {
        VStack(spacing: FeySpacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color(hex: 0x5C8571))
                .frame(width: 74, height: 74)
                .background(Color(hex: 0xE4ECE6), in: Circle())

            Text("Tout est à jour")
                .font(FeyFont.pageTitle)
                .foregroundStyle(FeyColor.ink)
                .tracking(FeyTracking.tight)
                .padding(.top, FeySpacing.xxs)

            Text("Aucune carte n'arrive à échéance. Vous pouvez réviser en avance depuis un cours.")
                .font(FeyFont.body)
                .foregroundStyle(FeyColor.inkTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FeySpacing.xl)
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
