import SwiftData
import SwiftUI

/// Écran d'ouverture de l'app : **Réviser**. Salutation, série, et la file du jour.
///
/// Il ne parle que de la révision du jour : pas de date, pas de liste de cours, pas de
/// bouton d'import — tout ça vit dans l'onglet Cours, à un balayage de là. Le bouton de
/// session est ancré en bas, donc visible sans faire défiler : entre le lancement de
/// l'app et la première carte, il n'y a qu'un appui.
struct TodayView: View {
    @Query private var allCards: [Flashcard]
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]
    @Query private var reviewLogs: [ReviewLog]

    @State private var showStudy = false
    @State private var path: [Course] = []
    @State private var showImportChoice = false
    @State private var pendingImport: ImportKind?
    @State private var activeImport: ImportKind?

    /// La file telle que la session va la servir : le plafond de cartes neuves du jour,
    /// hérité du rythme choisi à l'inscription, est déjà appliqué. Le chiffre affiché est
    /// donc exactement celui qu'on va réviser.
    private var dueCards: [Flashcard] {
        StudyQueueBuilder.build(from: allCards, limits: .daily())
    }

    /// Cartes neuves dues mais gardées pour les jours suivants, à cause du plafond.
    private var heldBackNewCards: Int {
        let dueNew = allCards.filter { $0.isDue() && $0.state == .new }.count
        return max(0, dueNew - newCount)
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

    private var streak: Int {
        StudyStats.streak(reviewDates: reviewLogs.map(\.reviewedAt))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    header

                    if dueCards.isEmpty {
                        restState
                    } else {
                        countBlock
                        dueCoursesSection
                        breakdownSection
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, hasSessionButton ? MicaboLayout.bottomBarClearance : MicaboSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            .overlay(alignment: .bottom) {
                if hasSessionButton {
                    MicaboBottomBar {
                        Button {
                            Haptics.medium()
                            showStudy = true
                        } label: {
                            Text(sessionButtonTitle)
                        }
                        .buttonStyle(MicaboPrimaryButtonStyle())
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .reportsPaging(for: .today, depth: path.count)
            .navigationDestination(for: Course.self) { course in
                FlashcardsView(course: course)
            }
        }
        .sheet(isPresented: $showImportChoice, onDismiss: launchPendingImport) {
            ImportChoiceSheet { kind in
                pendingImport = kind
                showImportChoice = false
            }
            .presentationDetents([.height(540)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .fullScreenCover(item: $activeImport) { kind in
            ImportView(kind: kind) { course in
                activeImport = nil
                path = [course]
            }
        }
        .fullScreenCover(isPresented: $showStudy) {
            // Rien à réviser : on ouvre franchement un entraînement libre plutôt que de
            // faire passer des cartes en avance pour une vraie session.
            StudyView(source: .allDue, mode: dueCards.isEmpty ? .practice : .scheduled)
        }
    }

    // MARK: - En-tête

    private var header: some View {
        MicaboScreenHeader(title: StudyStats.greeting(), eyebrow: headerEyebrow)
            .padding(.top, MicaboSpacing.xs)
    }

    /// La date du jour n'apparaît pas : l'écran dit déjà ce qu'il y a à faire
    /// aujourd'hui, et le téléphone porte l'heure juste au-dessus. Reste la série,
    /// qui est la seule chose que l'utilisateur risque de perdre.
    private var headerEyebrow: String? {
        guard streak > 0 else { return nil }
        return "Série de \(streak) jour\(streak > 1 ? "s" : "")"
    }

    // MARK: - Le chiffre du jour

    /// Posé à même le fond ivoire : pas de panneau, c'est déjà le sujet de l'écran.
    private var countBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("\(dueCards.count)")
                    .font(MicaboFont.hanken(76, weight: .bold))
                    .tracking(-2)
                    .foregroundStyle(MicaboColor.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(dueCards.count > 1 ? "cartes\nà réviser" : "carte\nà réviser")
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

            if heldBackNewCards > 0 {
                Text("\(MicaboCopy.cards(heldBackNewCards)) neuves gardées pour les jours suivants, pour tenir ton rythme de \(DailyLoad.label(forMinutes: OnboardingPreferences.dailyMinutes)) par jour.")
                    .font(MicaboFont.hanken(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private var dueCoursesSection: some View {
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

    /// Compté sur la file du jour, plafond compris : « au programme » doit dire la vérité.
    private var dueByCourse: [(course: Course, count: Int)] {
        var counts: [UUID: Int] = [:]
        for card in dueCards {
            guard let id = card.course?.id else { continue }
            counts[id, default: 0] += 1
        }

        let entries: [(course: Course, count: Int)] = courses.compactMap { course in
            guard let count = counts[course.id], count > 0 else { return nil }
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

    // MARK: - Rien à réviser

    @ViewBuilder
    private var restState: some View {
        if allCards.isEmpty {
            MicaboEmptyState(
                systemImage: "rectangle.on.rectangle.angled",
                title: "Pas encore de cartes",
                message: "Importe un cours : Micabo en tire tes premières cartes et te les repose au bon moment.",
                actionTitle: "Importer un cours"
            ) {
                showImportChoice = true
            }
        } else {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                doneState

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

            Text("Aucune carte à réviser aujourd'hui. Reviens demain, ou prends de l'avance.")
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MicaboSpacing.lg)
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

    // MARK: - Session

    /// Un seul bouton de session dans l'app, et il garde son nom d'un écran à l'autre.
    private var hasSessionButton: Bool {
        !allCards.isEmpty
    }

    private var sessionButtonTitle: String {
        dueCards.isEmpty ? "Entraînement libre" : MicaboCopy.reviewButton(count: dueCards.count)
    }

    // MARK: - Import

    private func launchPendingImport() {
        guard let kind = pendingImport else { return }
        pendingImport = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            activeImport = kind
        }
    }
}
