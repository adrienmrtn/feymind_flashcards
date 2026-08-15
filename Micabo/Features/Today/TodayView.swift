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
                        .padding(.bottom, MicaboSpacing.xl)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                            header
                            countBlock
                            breakdownCard
                            coursesSection
                        }
                        .padding(.horizontal, MicaboSpacing.screen)
                        .padding(.bottom, MicaboLayout.bottomBarClearance)
                    }
                    .scrollIndicators(.hidden)
                    .overlay(alignment: .bottom) {
                        MicaboBottomBar {
                            Button {
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
            .micaboTabBarClearance()
            .reportsNavigationDepth(for: .today, depth: path.count)
            .navigationDestination(for: Course.self) { course in
                FlashcardsView(course: course)
            }
        }
        .fullScreenCover(isPresented: $showStudy) {
            StudyView(source: .allDue)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(StudyStats.formattedDate())
                .font(MicaboFont.hanken(13, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)

            Text("Réviser")
                .font(MicaboFont.hanken(26, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.4)
        }
        .padding(.horizontal, dueCards.isEmpty ? MicaboSpacing.screen : 0)
        .padding(.top, MicaboSpacing.xs)
    }

    /// Le chiffre du jour, posé à même le fond ivoire : pas de panneau sombre.
    private var countBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(dueCards.count)")
                    .font(MicaboFont.hanken(72, weight: .bold))
                    .tracking(-1.5)
                    .foregroundStyle(MicaboColor.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.trailing, 6)

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

    private var breakdownCard: some View {
        VStack(spacing: 0) {
            breakdownRow(color: Color(hex: 0xC9B98A), label: "En révision", count: reviewCount)
            breakdownRow(color: MicaboColor.accent, label: "En apprentissage", count: learningCount)
            breakdownRow(color: Color(hex: 0x8A857B), label: "Nouvelles", count: newCount, isLast: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    private func breakdownRow(color: Color, label: String, count: Int, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(count > 0 ? color : MicaboColor.strokeStrong)
                    .frame(width: 8, height: 8)

                Text(label)
                    .font(MicaboFont.hanken(14, weight: .medium))
                    .foregroundStyle(count > 0 ? MicaboColor.ink : MicaboColor.inkTertiary)

                Spacer(minLength: 0)

                Text("\(count)")
                    .font(MicaboFont.hanken(14, weight: .semibold))
                    .foregroundStyle(count > 0 ? MicaboColor.ink : MicaboColor.inkTertiary)
                    .monospacedDigit()
            }
            .padding(.vertical, 12)

            if !isLast {
                Rectangle()
                    .fill(MicaboColor.stroke)
                    .frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private var coursesSection: some View {
        let entries = dueByCourse
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MicaboSectionHeader(title: "Au programme")

                VStack(spacing: 12) {
                    ForEach(entries, id: \.course.id) { entry in
                        Button {
                            path.append(entry.course)
                        } label: {
                            HStack(spacing: MicaboSpacing.sm) {
                                CourseThumb(course: entry.course)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.course.title)
                                        .font(MicaboFont.hanken(14, weight: .semibold))
                                        .foregroundStyle(MicaboColor.ink)
                                        .lineLimit(1)

                                    Text("\(entry.count) carte\(entry.count > 1 ? "s" : "") à revoir")
                                        .font(MicaboFont.hanken(12, weight: .regular))
                                        .foregroundStyle(MicaboColor.inkTertiary)
                                }

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(hex: 0xC9C3B8))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
                segment(color: Color(hex: 0xC9B98A), count: reviewCount, total: total, usable: usable)
                segment(color: MicaboColor.accent, count: learningCount, total: total, usable: usable)
                segment(color: Color(hex: 0xD8D2C6), count: newCount, total: total, usable: usable)
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder
    private func segment(color: Color, count: Int, total: Int, usable: CGFloat) -> some View {
        if count > 0 {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: max(4, usable * CGFloat(count) / CGFloat(total)))
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
                VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
                    MicaboSectionHeader(title: "Prochaines échéances")

                    ForEach(nextDueSummary, id: \.course.id) { entry in
                        HStack(spacing: MicaboSpacing.sm) {
                            CourseThumb(course: entry.course)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.course.title)
                                    .font(MicaboFont.bodyEmphasis)
                                    .foregroundStyle(MicaboColor.ink)
                                    .lineLimit(1)
                                Text(entry.label)
                                    .font(MicaboFont.micro)
                                    .foregroundStyle(MicaboColor.inkTertiary)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
            }
        }
    }

    private var doneState: some View {
        VStack(spacing: MicaboSpacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color(hex: 0x5C8571))
                .frame(width: 74, height: 74)
                .background(Color(hex: 0xE4ECE6), in: Circle())

            Text("Tout est à jour")
                .font(MicaboFont.hanken(18, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .padding(.top, MicaboSpacing.xxs)

            Text("Aucune carte due aujourd'hui. Revenez demain.")
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkTertiary)
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
