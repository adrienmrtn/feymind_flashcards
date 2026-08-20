import SwiftData
import SwiftUI

/// Écran « Réviser » : la file d'attente du jour, condensée en un seul chiffre,
/// puis un lancement plein écran de la session d'entraînement.
struct TodayView: View {
    @Query private var allCards: [Flashcard]
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var showStudy = false
    @State private var path: [Course] = []

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

    private var coursesWithDue: Int {
        Set(dueCards.compactMap { $0.course?.id }).count
    }

    private var estimatedMinutes: Int {
        max(1, Int((Double(dueCards.count) * 30 / 60).rounded(.up)))
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if dueCards.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                            header
                            emptyState
                        }
                        .padding(.horizontal, MicaboSpacing.screen)
                        .padding(.bottom, MicaboSpacing.xxl)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                            header
                            countBlock
                            coursesSection
                            breakdownSection
                        }
                        .padding(.horizontal, MicaboSpacing.screen)
                        .padding(.bottom, MicaboLayout.bottomBarClearance)
                    }
                    .scrollIndicators(.hidden)
                    .overlay(alignment: .bottom) {
                        MicaboBottomBar {
                            Button {
                                Haptics.medium()
                                showStudy = true
                            } label: {
                                Text("Commencer la session")
                            }
                            .buttonStyle(MicaboPrimaryButtonStyle())
                        }
                    }
                }
            }
            .micaboScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .micaboTabBar()
            .reportsPaging(for: .today, depth: path.count)
            .navigationDestination(for: Course.self) { course in
                FlashcardsView(course: course)
            }
        }
        .fullScreenCover(isPresented: $showStudy) {
            StudyView(source: .allDue)
        }
    }

    private var header: some View {
        MicaboScreenHeader(title: "Réviser", eyebrow: StudyStats.formattedDate())
            .padding(.top, MicaboSpacing.xs)
    }

    /// Le chiffre du jour, posé à même le fond ivoire : pas de panneau sombre.
    private var countBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("\(dueCards.count)")
                    .font(MicaboFont.hanken(76, weight: .bold))
                    .tracking(-2)
                    .foregroundStyle(MicaboColor.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(dueCards.count > 1 ? "cartes\nà revoir" : "carte\nà revoir")
                    .font(MicaboFont.hanken(16, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineSpacing(1)
                    .fixedSize()

                Spacer(minLength: 0)
            }

            Text("≈ \(estimatedMinutes) min · \(coursesWithDue > 1 ? "\(coursesWithDue) cours" : "1 cours")")
                .font(MicaboFont.hanken(13, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)

            progressSegments
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var coursesSection: some View {
        let entries = dueByCourse
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(text: "Au programme")

                MicaboRowGroup(
                    rows: entries.map { entry in
                        MicaboRow.courseDue(entry.course, dueCount: entry.count) {
                            path.append(entry.course)
                        }
                    }
                )
            }
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Répartition")

            VStack(spacing: 0) {
                breakdownRow(color: MicaboColor.caution, label: "En révision", count: reviewCount)
                MicaboHairline(inset: MicaboSpacing.md)
                breakdownRow(color: MicaboColor.accent, label: "En apprentissage", count: learningCount)
                MicaboHairline(inset: MicaboSpacing.md)
                breakdownRow(color: MicaboColor.inkTertiary, label: "Nouvelles", count: newCount)
            }
            .micaboGroup()
        }
    }

    private func breakdownRow(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 11) {
            Circle()
                .fill(count > 0 ? color : MicaboColor.surfaceSunken)
                .frame(width: 9, height: 9)

            Text(label)
                .font(MicaboFont.hanken(15, weight: .medium))
                .foregroundStyle(count > 0 ? MicaboColor.ink : MicaboColor.inkTertiary)

            Spacer(minLength: 0)

            Text("\(count)")
                .font(MicaboFont.hanken(15, weight: .semibold))
                .foregroundStyle(count > 0 ? MicaboColor.ink : MicaboColor.inkTertiary)
                .monospacedDigit()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, MicaboSpacing.md)
    }

    private var dueByCourse: [(course: Course, count: Int)] {
        let entries: [(course: Course, count: Int)] = courses.compactMap { course in
            let count = course.dueCards.count
            guard count > 0 else { return nil }
            return (course: course, count: count)
        }
        return entries.sorted { $0.count > $1.count }
    }

    private var progressSegments: some View {
        GeometryReader { proxy in
            let total = max(1, dueCards.count)
            let spacing: CGFloat = 4
            let usable = max(0, proxy.size.width - spacing * 2)

            HStack(spacing: spacing) {
                segment(color: MicaboColor.caution, count: reviewCount, total: total, usable: usable)
                segment(color: MicaboColor.accent, count: learningCount, total: total, usable: usable)
                segment(color: MicaboColor.surfaceSunken, count: newCount, total: total, usable: usable)
            }
        }
        .frame(height: 7)
    }

    @ViewBuilder
    private func segment(color: Color, count: Int, total: Int, usable: CGFloat) -> some View {
        if count > 0 {
            Capsule()
                .fill(color)
                .frame(width: max(5, usable * CGFloat(count) / CGFloat(total)))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
            if allCards.isEmpty {
                MicaboEmptyState(
                    systemImage: "rectangle.on.rectangle.angled",
                    title: "Pas encore de flashcards",
                    message: "Importez un cours pour créer vos premières flashcards et démarrer la répétition espacée."
                )
            } else {
                doneState
            }

            if !nextDueSummary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    MicaboSectionCaption(text: "Prochaines échéances")

                    MicaboRowGroup(
                        rows: nextDueSummary.map { entry in
                            MicaboRow(
                                tile: MicaboTile.course(entry.course),
                                title: entry.course.title,
                                subtitle: entry.label,
                                accessory: .none
                            )
                        }
                    )
                }
            }
        }
    }

    private var doneState: some View {
        VStack(spacing: MicaboSpacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(MicaboColor.positive)
                .frame(width: 76, height: 76)
                .background(MicaboColor.positiveSoft, in: Circle())

            Text("Tout est à jour")
                .font(MicaboFont.hanken(19, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.3)
                .padding(.top, MicaboSpacing.xxs)

            Text("Aucune carte due aujourd'hui. Revenez demain.")
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MicaboSpacing.xl)
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
