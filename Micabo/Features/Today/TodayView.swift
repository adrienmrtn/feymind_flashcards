import SwiftData
import SwiftUI

/// Écran d'ouverture de l'app : **Réviser**. Le chiffre du jour, et ce qu'il contient.
///
/// Il ne parle que de la révision du jour : pas de date, pas de liste de cours, pas de
/// bouton d'import — tout ça vit dans l'onglet Cours. Le bouton de session est ancré en bas,
/// donc visible sans faire défiler : entre le lancement de l'app et la première carte, il
/// n'y a qu'un appui.
///
/// **Le haut de l'écran a été refait.** Il portait une salutation en grand
/// (« Bonsoir »), un sur-titre de série, un nombre de 76 points posé à même le fond avec
/// deux lignes de légende à sa droite, une barre segmentée sans légende, puis un bloc
/// « Répartition » qui redonnait en rangées les trois chiffres de la barre. Beaucoup de
/// hauteur, trois niveaux de gris, et deux fois la même information.
///
/// Il ne reste qu'un titre d'écran, la série en pastille à sa droite, et **une seule carte**
/// qui porte le chiffre, la durée, la barre et sa légende. La barre devient lisible parce
/// qu'elle est légendée juste dessous, et le bloc « Répartition » disparaît puisque c'est
/// exactement ce que la légende dit.
struct TodayView: View {
    @Query private var allCards: [Flashcard]
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]
    @Query(sort: \Exam.date, order: .forward) private var exams: [Exam]

    @Environment(\.modelContext) private var modelContext
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(TabRouter.self) private var router: TabRouter?
    @Environment(CloudSync.self) private var sync: CloudSync?

    @State private var showStudy = false
    @State private var path = NavigationPath()
    @State private var showImportChoice = false
    @State private var pendingImport: ImportKind?
    @State private var activeImport: ImportKind?
    /// Un paquet de cartes ne passe pas par l'écran d'import : il n'y a rien à lire.
    @State private var isCreatingDeck = false
    @State private var paywall: PaywallTrigger?

    /// Dernière file calculée. Une bascule de feuille, de paywall ou de navigation ne change
    /// aucune échéance : elle ne doit pas reconstruire toutes les cartes du jour.
    @State private var loadBox = DayLoadBox()

    /// File du jour, calculée **une fois** par rendu. Sans ça, `StudyQueueBuilder.build`
    /// tournait à chaque lecture de `dueCards` — une dizaine de fois par frame, y compris
    /// quand l'onglet n'est pas celui qu'on regarde.
    private struct DayLoad {
        let dueCards: [Flashcard]
        let heldBackNewCards: Int
        let newCount: Int
        let learningCount: Int
        let reviewCount: Int
        let coursesWithDue: Int
        let estimatedMinutes: Int
        let dueByCourse: [(course: Course, count: Int)]

        let streak: Int

        init(allCards: [Flashcard], courses: [Course], exams: [Exam], todayLogs: [ReviewLog], streak: Int) {
            self.streak = streak
            let due = StudyQueueBuilder.build(
                from: allCards,
                limits: .daily(newRemaining: DailyNewQuota.remaining(logs: todayLogs)),
                deadlines: ExamDeadlines.active(exams: exams, cards: allCards)
            )
            dueCards = due
            newCount = due.filter { $0.state == .new }.count
            learningCount = due.filter { $0.state == .learning || $0.state == .relearning }.count
            reviewCount = due.filter { $0.state == .review }.count
            let dueNew = allCards.filter { $0.isDue() && $0.state == .new }.count
            heldBackNewCards = max(0, dueNew - newCount)
            coursesWithDue = Set(due.compactMap { $0.course?.id }).count
            estimatedMinutes = max(1, Int((Double(due.count) * 30 / 60).rounded(.up)))

            var counts: [UUID: Int] = [:]
            for card in due {
                guard let id = card.course?.id else { continue }
                counts[id, default: 0] += 1
            }
            dueByCourse = courses.compactMap { course in
                guard let count = counts[course.id], count > 0 else { return nil }
                return (course: course, count: count)
            }
            .sorted { $0.count > $1.count }
        }
    }

    private final class DayLoadBox {
        var key: DayLoadKey?
        var value: DayLoad?
    }

    private struct DayLoadKey: Equatable {
        let day: Date
        let minute: Int
        let cardCount: Int
        let cardStamp: Date?
        let courseCount: Int
        let courseStamp: Date?
        let examCount: Int
        let examStamp: Date?
        let syncEpoch: Int
    }

    private func dayLoadKey(now: Date = Date()) -> DayLoadKey {
        DayLoadKey(
            day: MicaboCalendar.shared.startOfDay(for: now),
            minute: Int(now.timeIntervalSince1970 / 60),
            cardCount: allCards.count,
            cardStamp: allCards.map(\.updatedAt).max(),
            courseCount: courses.count,
            courseStamp: courses.map(\.updatedAt).max(),
            examCount: exams.count,
            examStamp: exams.map(\.updatedAt).max(),
            syncEpoch: sync?.epoch ?? 0
        )
    }

    private func resolvedLoad() -> DayLoad {
        let key = dayLoadKey()
        if let cached = loadBox.value {
            if loadBox.key == key { return cached }
            // L'onglet n'est pas visible, ou la synchro écrit encore : on attend la fin du
            // lot au lieu de reconstruire après chaque ligne descendue.
            if router?.selection != .today { return cached }
            if sync?.state == .syncing { return cached }
        }
        let built = DayLoad(
            allCards: allCards,
            courses: courses,
            exams: exams,
            todayLogs: todayLogs(),
            streak: currentStreak()
        )
        loadBox.key = key
        loadBox.value = built
        return built
    }

    private var nextExam: Exam? {
        upcomingExams.first
    }

    private var upcomingExams: [Exam] {
        Array(exams.filter { !$0.isPast() }.prefix(5))
    }

    /// Journaux **du jour** seulement : le quota n'a pas besoin de tout l'historique.
    /// Relire chaque note jamais donnée à chaque rendu de Réviser était le coût caché
    /// de cet écran.
    private func todayLogs(now: Date = Date()) -> [ReviewLog] {
        let start = MicaboCalendar.shared.startOfDay(for: now)
        return (try? modelContext.fetch(FetchDescriptor<ReviewLog>(
            predicate: #Predicate { $0.reviewedAt >= start }
        ))) ?? []
    }

    private func currentStreak() -> Int {
        let dates = (try? modelContext.fetch(FetchDescriptor<ReviewLog>()))?.map(\.reviewedAt) ?? []
        return StudyStats.streak(reviewDates: dates)
    }

    var body: some View {
        today(resolvedLoad())
    }

    @ViewBuilder
    private func today(_ load: DayLoad) -> some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    header(streak: load.streak)

                    if load.dueCards.isEmpty && load.heldBackNewCards == 0 {
                        restState
                    } else if load.dueCards.isEmpty {
                        rhythmReachedCard(held: load.heldBackNewCards)
                        dueCoursesSection(load.dueByCourse)
                    } else {
                        dueCard(load)
                        dueCoursesSection(load.dueByCourse)
                    }

                    examSection
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboSpacing.md)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            // Le bouton de session se pose au-dessus de la barre d'onglets, et la page
            // réserve la hauteur des deux. C'est la page qui doit le faire : l'inset de la
            // racine ne franchit pas la frontière du `NavigationStack`, et le premier appui
            // de l'app passait sous la barre dès qu'il apparaissait — voir
            // `tabBarClearance`.
            .tabBarClearance {
                if hasSessionButton {
                    MicaboBottomBar {
                        Button(action: startSession) {
                            HStack(spacing: MicaboSpacing.xs) {
                                Text(sessionButtonTitle(load))

                                if load.dueCards.isEmpty, !canPractice {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11, weight: .bold))
                                }
                            }
                        }
                        .buttonStyle(MicaboPrimaryButtonStyle())
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .reportsNavigationDepth(for: .today, depth: path.count)
            .returnsHome(path: $path)
            .navigationDestination(for: Course.self) { course in
                CourseSheetView(course: course)
            }
            .navigationDestination(for: CourseCardsRoute.self) { route in
                FlashcardsView(course: route.course)
            }
        }
        .sheet(isPresented: $showImportChoice, onDismiss: launchPendingImport) {
            ImportChoiceSheet(
                onSelect: { kind in
                    pendingImport = kind
                    showImportChoice = false
                }
            )
            .presentationDetents([.height(604)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .fullScreenCover(item: $activeImport) { kind in
            ImportView(kind: kind) { course in
                activeImport = nil
                path = NavigationPath([course])
            }
        }
        .fullScreenCover(isPresented: $isCreatingDeck) {
            CreateDeckView { course in
                isCreatingDeck = false
                path = NavigationPath([CourseCardsRoute(course: course)])
            }
        }
        .fullScreenCover(isPresented: $showStudy) {
            // Le rythme du jour est atteint mais il reste des neuves : on ouvre quand
            // même une session réglable, pas un entraînement libre.
            StudyView(
                source: .allDue,
                mode: load.dueCards.isEmpty && load.heldBackNewCards == 0 ? .practice : .scheduled
            )
        }
        .micaboPaywall($paywall)
    }

    // MARK: - En-tête

    /// Le titre de l'écran, et la série à sa droite. Pas de salutation : c'est le seul
    /// endroit de l'app où l'on ouvre, et ce qu'on vient y chercher est le chiffre juste
    /// dessous.
    private func header(streak: Int) -> some View {
        MicaboScreenHeader(title: "Réviser") {
            if streak > 0 {
                streakPill(streak)
            }
        }
        .padding(.top, MicaboSpacing.xs)
    }

    /// La série est la seule chose que l'utilisateur risque de perdre : elle mérite d'être
    /// visible, pas d'être un sur-titre gris au-dessus du titre.
    private func streakPill(_ streak: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .semibold))

            Text("\(streak) j")
                .font(MicaboFont.number(14, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(MicaboColor.caution)
        .padding(.vertical, 8)
        .padding(.horizontal, 13)
        .background(MicaboColor.cautionSoft, in: Capsule())
        .accessibilityLabel("Série de \(streak) jour\(streak > 1 ? "s" : "")")
    }

    // MARK: - Le chiffre du jour

    /// **Une seule carte pour tout ce qui décrit la file du jour** : le chiffre, ce qu'il
    /// coûte en temps, et de quoi il est fait. Les quatre blocs qui se succédaient à même le
    /// fond donnaient trois gris à lire de haut en bas ; là, il y a un objet à regarder.
    private func dueCard(_ load: DayLoad) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                Text("\(load.dueCards.count)")
                    .font(MicaboFont.number(58))
                    .tracking(-1.5)
                    .foregroundStyle(MicaboColor.ink)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: Double(load.dueCards.count)))
                    .animation(.easeOut(duration: 0.3), value: load.dueCards.count)

                VStack(alignment: .leading, spacing: 3) {
                    Text(load.dueCards.count > 1 ? "cartes à réviser" : "carte à réviser")
                        .font(MicaboFont.hanken(16, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("≈ \(load.estimatedMinutes) min · \(load.coursesWithDue > 1 ? "\(load.coursesWithDue) cours" : "1 cours")")
                        .font(MicaboFont.hanken(13, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 11) {
                progressSegments(load)
                legend(load)
            }

            if load.heldBackNewCards > 0 {
                heldBackNote(load.heldBackNewCards)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dueCardAccessibility(load))
    }

    private func dueCardAccessibility(_ load: DayLoad) -> String {
        let parts = visibleSegments(load).map { "\($0.count) \($0.label)" }
        var label = "\(MicaboCopy.cards(load.dueCards.count)) à réviser"
        if !parts.isEmpty { label += ". " + parts.joined(separator: ", ") }
        if load.heldBackNewCards > 0 { label += ". " + MicaboCopy.heldBackNew(load.heldBackNewCards) }
        return label
    }

    /// Ce que la barre veut dire. Sans elle, trois couleurs empilées ne sont qu'un
    /// dégradé — et c'est pour la remplacer qu'un bloc « Répartition » existait plus bas.
    private func legend(_ load: DayLoad) -> some View {
        MicaboFlowLayout(spacing: 14, lineSpacing: 7) {
            ForEach(visibleSegments(load)) { segment in
                HStack(spacing: 6) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: 7, height: 7)

                    Text("\(segment.count) \(segment.label)")
                        .font(MicaboFont.hanken(12.5, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
    }

    /// Dit pourquoi le chiffre du haut est plus petit que le nombre de cartes réellement
    /// dues : sans cette ligne, le plafond de rythme passerait pour un bug.
    private func heldBackNote(_ heldBackNewCards: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)

            Text(MicaboCopy.heldBackNew(heldBackNewCards))
                .font(MicaboFont.hanken(12, weight: .regular))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func dueCoursesSection(_ entries: [(course: Course, count: Int)]) -> some View {
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

    // MARK: - Examens

    /// L'entrée vers l'onglet Examens, et le compte à rebours du prochain.
    ///
    /// Elle reste ici parce qu'un examen oriente la file du jour. Un appui ouvre l'onglet,
    /// plus un écran poussé : le calendrier a sa propre place dans la barre.
    /// **La rangée des examens est toujours là**, même sans un seul cours.
    private var examSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Prochains examens")

            if upcomingExams.isEmpty {
                Button {
                    openExams()
                } label: {
                    MicaboRow(
                        tile: MicaboTile(
                            glyph: .symbol("calendar"),
                            background: MicaboColor.surfaceMuted,
                            tint: MicaboColor.inkSecondary
                        ),
                        title: "Planifier un examen",
                        subtitle: examEmptySubtitle,
                        accessory: .chevron
                    )
                }
                .buttonStyle(MicaboRowButtonStyle())
                .micaboGroup()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcomingExams.enumerated()), id: \.element.id) { index, exam in
                        Button {
                            openExams()
                        } label: {
                            MicaboRow(
                                tile: MicaboTile(
                                    glyph: .symbol("calendar"),
                                    background: MicaboColor.cautionSoft,
                                    tint: MicaboColor.caution
                                ),
                                title: exam.name,
                                subtitle: examLine(exam),
                                accessory: .badge(exam.countdownLabel(), .warm)
                            )
                        }
                        .buttonStyle(MicaboRowButtonStyle())

                        if index < upcomingExams.count - 1 {
                            MicaboHairline(inset: 71)
                        }
                    }
                }
                .micaboGroup()
            }
        }
    }

    private func openExams() {
        router?.selection = .exams
    }

    private var examEmptySubtitle: String {
        allCards.isEmpty ? "Quand tu auras des cartes" : "Ajouter une date"
    }

    private func examLine(_ exam: Exam) -> String {
        let grade = DesiredGradeScale.for(OnboardingPreferences.schoolingCountry).label(for: exam.targetScore)
        return "\(grade) souhaitée · \(examProgress(exam)) % d'avancée"
    }

    /// Cartes déjà introduites parmi celles des cours de l'examen.
    private func examProgress(_ exam: Exam) -> Int {
        let relevant = allCards.filter { card in
            guard !card.isSuspended, let courseID = card.course?.id else { return false }
            return exam.courseIDs.contains(courseID)
        }
        guard !relevant.isEmpty else { return 0 }
        let started = relevant.filter { $0.state != .new }.count
        return Int((Double(started) / Double(relevant.count) * 100).rounded())
    }

    // MARK: - La barre et sa légende

    /// Les trois natures de cartes de la file, dans l'ordre où elles se lisent. Une seule
    /// source pour la barre et pour sa légende : deux listes séparées finiraient par ne plus
    /// dire la même chose.
    private struct Segment: Identifiable {
        let label: String
        let color: Color
        let count: Int

        var id: String { label }
    }

    /// Une part de la barre, une fois sa largeur arrêtée.
    private struct SizedSegment: Identifiable {
        let id: String
        let color: Color
        let width: CGFloat
    }

    private func visibleSegments(_ load: DayLoad) -> [Segment] {
        [
            Segment(label: "en révision", color: MicaboColor.caution, count: load.reviewCount),
            Segment(label: "en apprentissage", color: MicaboColor.accent, count: load.learningCount),
            Segment(label: "nouvelles", color: MicaboColor.inkTertiary, count: load.newCount)
        ]
        .filter { $0.count > 0 }
    }

    private func progressSegments(_ load: DayLoad) -> some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 3

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MicaboColor.surfaceMuted)

                HStack(spacing: spacing) {
                    ForEach(segmentWidths(load, in: proxy.size.width, spacing: spacing)) { entry in
                        Capsule()
                            .fill(entry.color)
                            .frame(width: entry.width)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: 8)
        .animation(.easeOut(duration: 0.3), value: load.dueCards.count)
    }

    /// Les largeurs sont calculées puis **renormalisées**. Chaque part reçoit un plancher de
    /// six points, sans quoi une seule carte neuve dans une file de cinquante ne se voit
    /// pas ; ces planchers mis bout à bout peuvent dépasser la largeur disponible, et une
    /// rangée qui dépasse déborde de la carte.
    private func segmentWidths(_ load: DayLoad, in width: CGFloat, spacing: CGFloat) -> [SizedSegment] {
        let segments = visibleSegments(load)
        let usable = width - spacing * CGFloat(max(0, segments.count - 1))
        guard !segments.isEmpty, usable > 0 else { return [] }

        let total = CGFloat(max(1, load.dueCards.count))
        var widths = segments.map { max(6, usable * CGFloat($0.count) / total) }

        let sum = widths.reduce(0, +)
        if sum > usable {
            widths = widths.map { $0 * usable / sum }
        }

        return zip(segments, widths).map { SizedSegment(id: $0.label, color: $0.color, width: $1) }
    }

    // MARK: - Rien à réviser

    @ViewBuilder
    private var restState: some View {
        if allCards.isEmpty {
            MicaboEmptyState(
                systemImage: "rectangle.on.rectangle.angled",
                title: "Pas encore de cartes",
                message: "Importe un cours pour commencer.",
                actionTitle: "Importer"
            ) {
                requestImport()
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

    /// Le rythme est tenu, mais des cartes neuves attendent encore. On le dit,
    /// plutôt que d'afficher « Tout est à jour » alors qu'il reste à apprendre.
    private func rhythmReachedCard(held heldBackNewCards: Int) -> some View {
        reviewDoneCard(subtitle: MicaboCopy.heldBackNew(heldBackNewCards))
    }

    private var doneState: some View {
        reviewDoneCard(subtitle: "Ta révision du jour est terminée.")
    }

    /// Le tick vert est le sujet : sans lui, « C'est fait » se lisait comme une légende.
    private func reviewDoneCard(subtitle: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(MicaboColor.accentVivid)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("C'est fait")
                    .font(MicaboFont.hanken(22, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)

                Text(subtitle)
                    .font(MicaboFont.hanken(14.5, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 18)
        .micaboGroup()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("C'est fait. \(subtitle)")
    }

    private var nextDueSummary: [(course: Course, label: String)] {
        var earliest: [UUID: Date] = [:]
        for card in allCards where !card.isSuspended {
            guard let courseID = card.course?.id else { continue }
            if let existing = earliest[courseID] {
                if card.dueDate < existing { earliest[courseID] = card.dueDate }
            } else {
                earliest[courseID] = card.dueDate
            }
        }
        return courses.compactMap { course in
            guard let next = earliest[course.id] else { return nil }
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

    private func sessionButtonTitle(_ load: DayLoad) -> String {
        if !load.dueCards.isEmpty { return MicaboCopy.reviewButton(count: load.dueCards.count) }
        if load.heldBackNewCards > 0 { return "Réviser" }
        return MicaboCopy.practiceReview
    }

    private var canPractice: Bool { pro?.canPractice ?? true }

    /// Réviser ce qui est dû reste gratuit. Prendre de l'avance sur tout un paquet, non :
    /// c'est ce qu'on fait la veille d'un partiel, et c'est ce que Pro ouvre.
    private func startSession() {
        let load = resolvedLoad()
        guard !load.dueCards.isEmpty || load.heldBackNewCards > 0 || canPractice else {
            paywall = .practice
            return
        }
        showStudy = true
    }

    // MARK: - Import

    /// Le premier cours est offert, le deuxième s'achète.
    ///
    /// Le contrôle est ici plutôt que dans l'écran d'import : on refuse **avant** d'avoir
    /// fait choisir un PDF, sélectionner des photos et attendre une analyse. Un paywall qui
    /// tombe après le travail est un paywall qui fait désinstaller.
    private func requestImport() {
        guard pro?.canImportCourse(existingCourses: courses) ?? true else {
            paywall = .secondCourse
            return
        }
        showImportChoice = true
    }

    private func launchPendingImport() {
        guard let kind = pendingImport else { return }
        pendingImport = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if kind.producesSheet {
                activeImport = kind
            } else {
                isCreatingDeck = true
            }
        }
    }
}
