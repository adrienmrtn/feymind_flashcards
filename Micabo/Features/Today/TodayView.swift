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

    private var estimatedMinutes: Int {
        max(1, Int((Double(dueCards.count) * 30 / 60).rounded(.up)))
    }

    var body: some View {
        NavigationStack {
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
                    VStack(spacing: 0) {
                        header
                        sessionCard
                            .padding(.horizontal, MicaboSpacing.screen)
                            .padding(.bottom, MicaboSpacing.md)
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .micaboScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showStudy) {
            StudyView(source: .allDue)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Réviser")
                .font(MicaboFont.hanken(26, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.4)

            Spacer(minLength: MicaboSpacing.sm)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.xs)
        .padding(.bottom, MicaboSpacing.sm)
    }

    private var sessionCard: some View {
        VStack(spacing: 22) {
            HStack {
                Text("SESSION DU JOUR")
                    .font(MicaboFont.hanken(12, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(Color(hex: 0x8F8B82))

                Spacer()

                Text(coursesWithDue > 1 ? "\(coursesWithDue) cours" : "1 cours")
                    .font(MicaboFont.hanken(12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xC9B98A))
            }

            VStack(spacing: 8) {
                Text("\(dueCards.count)")
                    .font(MicaboFont.hanken(112, weight: .bold))
                    .tracking(-4)
                    .foregroundStyle(MicaboColor.onInk)
                    .minimumScaleFactor(0.35)
                    .lineLimit(1)

                Text(dueCards.count > 1 ? "cartes dues aujourd'hui" : "carte due aujourd'hui")
                    .font(MicaboFont.hanken(16, weight: .medium))
                    .foregroundStyle(Color(hex: 0x9A958A))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 14) {
                progressSegments

                HStack {
                    Text(breakdownLabel)
                        .font(MicaboFont.hanken(12, weight: .regular))
                        .foregroundStyle(Color(hex: 0x8F8B82))
                    Spacer()
                    Text("≈ \(estimatedMinutes) min")
                        .font(MicaboFont.hanken(12, weight: .regular))
                        .foregroundStyle(Color(hex: 0x8F8B82))
                }

                Button {
                    showStudy = true
                } label: {
                    Text("Commencer la session")
                        .font(MicaboFont.hanken(15, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MicaboColor.ink, in: RoundedRectangle(cornerRadius: MicaboRadius.xxl, style: .continuous))
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
                segment(color: MicaboColor.accent, count: learningCount, total: total, usable: usable)
                segment(color: Color(hex: 0x4A463F), count: newCount, total: total, usable: usable)
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
