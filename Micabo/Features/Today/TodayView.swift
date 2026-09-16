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
///
/// **Le titre est le nom de l'écran**, avec la date en sur-titre. C'était « Bonsoir,
/// Adrien » : la plus grosse typographie de la page employée à ne rien dire, et le chiffre
/// du jour repoussé d'autant. Et la prochaine épreuve a sa carte, avec ce qu'on en sait
/// aujourd'hui posé contre l'objectif - c'est ce qui oriente la file du jour.
struct TodayView: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]
    @Query(sort: \Exam.date, order: .forward) private var exams: [Exam]

    @Environment(\.modelContext) private var modelContext
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(TabRouter.self) private var router: TabRouter?
    @Environment(CloudSync.self) private var sync: CloudSync?
    @Environment(MockExamService.self) private var mocks: MockExamService?
    @Environment(AuthController.self) private var auth: AuthController?

    @State private var showStudy = false
    @State private var path = NavigationPath()
    @State private var showImportChoice = false
    @State private var pendingImport: ImportKind?
    @State private var activeImport: ImportKind?
    @State private var paywall: PaywallTrigger?

    /// La file du jour, **lue à la demande et non observée**.
    ///
    /// L'écran tenait toutes les cartes dans un `@Query`. SwiftData rematérialisait alors la
    /// table entière sur l'acteur principal à chaque écriture - une carte notée, une ligne
    /// descendue par la synchro - et redessinait l'onglet, même quand on n'était pas dessus.
    /// Avec quelques cours, c'est des milliers d'objets reconstruits plusieurs fois par
    /// seconde pendant une session ou une synchro : c'est ça qui faisait ramer l'app.
    ///
    /// Les cartes se lisent maintenant en une requête, quand quelque chose a pu changer la
    /// file : l'onglet qui revient, une synchro finie, une session fermée, un cours ou un
    /// examen ajouté, le jour qui tourne. Entre deux, rien ne bouge et rien n'est relu.
    @State private var load: DayLoad?
    /// Les mesures qui tombent aujourd'hui, toutes épreuves confondues.
    @State private var measuresToday: [AgendaEvent] = []
    /// La copie ouverte en plein écran, qu'on vienne de l'ouvrir ou qu'on la reprenne, et le
    /// nom de son épreuve : `MockPaperView` les veut séparés.
    @State private var paper: MockSessionRecord?
    @State private var paperExamName = ""
    /// Le rendez-vous dont on attend la réponse sur le micro.
    @State private var starting: AgendaEvent?
    @State private var writingMock = false
    /// Compte les sessions fermées depuis cet écran : chacune change la file.
    @State private var studyRuns = 0

    private struct DayLoad {
        let totalCards: Int
        let dueCards: [Flashcard]
        let heldBackNewCards: Int
        let newCount: Int
        let learningCount: Int
        let reviewCount: Int
        let coursesWithDue: Int
        let estimatedMinutes: Int
        let dueByCourse: [(course: Course, count: Int)]
        let nextDue: [(course: Course, due: Date)]
        let examProgress: [UUID: Int]

        let streak: Int

        static let empty = DayLoad(allCards: [], courses: [], exams: [], todayLogs: [], logs: [:], streak: 0)

        init(
            allCards: [Flashcard],
            courses: [Course],
            exams: [Exam],
            todayLogs: [ReviewLog],
            logs: ExamReadiness.LogsByCard,
            streak: Int
        ) {
            self.streak = streak
            totalCards = allCards.count
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

            var earliest: [UUID: Date] = [:]
            for card in allCards where !card.isSuspended {
                guard let courseID = card.course?.id else { continue }
                if let existing = earliest[courseID] {
                    if card.dueDate < existing { earliest[courseID] = card.dueDate }
                } else {
                    earliest[courseID] = card.dueDate
                }
            }
            let now = Date()
            nextDue = courses.compactMap { course in
                guard let next = earliest[course.id], next.timeIntervalSince(now) > 0 else { return nil }
                return (course, next)
            }
            .prefix(4)
            .map { $0 }

            // « Appris à x % » : la même maîtrise que la fiche d'épreuve et que le site, pas
            // la part de cartes commencées.
            var progress: [UUID: Int] = [:]
            for exam in exams where !exam.isPast(from: now) {
                let relevant = allCards.filter { card in
                    guard !card.isSuspended, let courseID = card.course?.id else { return false }
                    return exam.courseIDs.contains(courseID)
                }
                guard !relevant.isEmpty else { continue }
                progress[exam.id] = ExamReadiness.masteryPercent(of: relevant, logs: logs, now: now)
            }
            examProgress = progress
        }
    }

    /// Ce qui fait relire la file. Le jour y est : une carte qui devient due à minuit ne
    /// prévient personne.
    private var reloadKey: String {
        let day = MicaboCalendar.shared.startOfDay(for: Date()).timeIntervalSince1970
        let examStamp = exams.map(\.updatedAt.timeIntervalSince1970).max() ?? 0
        return "\(router?.selection == .today)-\(sync?.epoch ?? 0)-\(courses.count)-\(exams.count)-\(examStamp)-\(day)-\(studyRuns)"
    }

    /// Deux lectures de table - les cartes, le journal récent - et la file est prête.
    private func reload() {
        // L'onglet qu'on ne regarde pas attend qu'on y revienne ; la première ouverture, elle,
        // charge quoi qu'il arrive pour que la barre d'onglets ait un chiffre à montrer.
        guard load == nil || router?.selection == .today else { return }
        guard sync?.state != .syncing || load == nil else { return }
        let cards = CourseRepository.allCards(in: modelContext)
        load = DayLoad(
            allCards: cards,
            courses: courses,
            exams: exams,
            todayLogs: todayLogs(),
            logs: ExamReadiness.recentLogsByCard(in: modelContext),
            streak: currentStreak()
        )
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
        if ReviewStreakStore.isFresh() { return ReviewStreakStore.current }
        let dates = (try? modelContext.fetch(FetchDescriptor<ReviewLog>()))?.map(\.reviewedAt) ?? []
        let streak = StudyStats.streak(reviewDates: dates)
        ReviewStreakStore.remember(streak: streak, best: StudyStats.bestStreak(reviewDates: dates))
        return streak
    }

    var body: some View {
        today(load ?? .empty)
            .task(id: reloadKey) { reload() }
            .task(id: "\(reloadKey)-measures") { await loadMeasures() }
            .sheet(item: $starting) { event in
                StartMockSheet { withAudio in
                    start(event, withAudio: withAudio)
                }
                .presentationDetents([.height(300), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(MicaboRadius.sheet)
            }
            .fullScreenCover(item: $paper) { session in
                MockPaperView(session: session, examName: paperExamName) { _ in
                    paper = nil
                    Task { await loadMeasures() }
                }
            }
            .overlay {
                if writingMock { MockWritingOverlay() }
            }
    }

    /// **Les mesures qui tombent aujourd'hui, et la copie qu'on aurait laissée ouverte.**
    ///
    /// Trois épreuves au plus. Au-delà, on paierait des requêtes pour des rendez-vous qui ne
    /// tomberont pas aujourd'hui : l'agenda d'une épreuve à deux mois est vide de ce côté-ci.
    private func loadMeasures() async {
        guard let mocks, auth?.user != nil else {
            measuresToday = []
            return
        }

        var found: [AgendaEvent] = []
        let today = MicaboCalendar.shared.startOfDay(for: Date())

        for exam in upcomingExams.prefix(3) {
            do {
                let sessions = try await mocks.sessions(for: exam.id)

                // Une copie laissée ouverte se reprend d'ici : c'est le seul écran qui la
                // propose maintenant, et l'abandonner en silence perdrait le temps déjà passé.
                if let open = sessions.first(where: { !$0.isFinished }), paper == nil {
                    paperExamName = exam.name
                    paper = open
                }

                let cards = ExamRepository.cards(of: exam, in: modelContext).count
                let events = ExamAgenda.events(
                    for: exam,
                    cardCount: cards,
                    done: MockExamService.done(from: sessions),
                    overrides: try await mocks.overrides(for: exam.id),
                    now: today
                )
                found += events.filter {
                    $0.status == .upcoming && MicaboCalendar.shared.startOfDay(for: $0.date) == today
                }
            } catch {
                // Une mesure qu'on ne peut pas lire n'est pas une panne à annoncer : la
                // journée reste utile sans elle, et la prochaine ouverture réessaiera.
            }
        }

        measuresToday = found
    }

    private func start(_ event: AgendaEvent, withAudio: Bool) {
        guard let mocks, !writingMock,
              let exam = exams.first(where: { $0.id == event.examId }) else { return }
        withAnimation(.easeOut(duration: 0.2)) { writingMock = true }
        Task {
            do {
                let session = try await mocks.start(
                    exam: exam,
                    courses: courses,
                    withAudio: withAudio,
                    kind: event.kind
                )
                withAnimation(.easeOut(duration: 0.2)) { writingMock = false }
                paperExamName = exam.name
                paper = session
            } catch {
                withAnimation(.easeOut(duration: 0.2)) { writingMock = false }
                Haptics.warning()
            }
        }
    }

    @ViewBuilder
    private func today(_ load: DayLoad) -> some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    header(streak: load.streak)

                    if load.dueCards.isEmpty && load.heldBackNewCards == 0 {
                        restState(load)
                    } else if load.dueCards.isEmpty {
                        rhythmReachedCard(held: load.heldBackNewCards)
                        dueCoursesSection(load.dueByCourse)
                    } else {
                        dueCard(load)
                        dueCoursesSection(load.dueByCourse)
                    }

                    examSection(load)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboSpacing.md)
                // Un `ScrollView` vertical défile quand même en travers dès que son
                // contenu dépasse en largeur. Borner la pile à la largeur proposée est
                // ce qui l'en empêche.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            // Le bouton de session se pose juste au-dessus de la barre d'onglets —
            // voir `tabBarClearance`.
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
            .navigationDestination(for: Exam.self) { exam in
                ExamDetailView(exam: exam)
            }
        }
        .sheet(isPresented: $showImportChoice, onDismiss: launchPendingImport) {
            ImportChoiceSheet(
                onSelect: { kind in
                    pendingImport = kind
                    showImportChoice = false
                }
            )
            .presentationDetents([.height(520)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .fullScreenCover(item: $activeImport) { kind in
            ImportView(kind: kind) { course in
                activeImport = nil
                path = NavigationPath([course])
            }
        }
        .fullScreenCover(isPresented: $showStudy, onDismiss: { studyRuns += 1 }) {
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

    /// Le nom de l'écran, la date en sur-titre, et la série à droite. Le chiffre du jour
    /// reste juste dessous : on ouvre, on lit, on lance.
    ///
    /// **Le titre était une salutation** — « Bonsoir, Adrien », en trente points, tout en
    /// haut. C'est la plus grosse typographie de l'écran employée à ne rien dire : elle ne
    /// renseigne sur rien, elle ne mène nulle part, et elle repousse d'autant le seul
    /// chiffre qu'on est venu voir. Les quatre autres onglets portent leur nom ; celui-ci
    /// porte maintenant le sien, et l'heure qu'il est se lit dans la date juste au-dessus.
    private func header(streak: Int) -> some View {
        MicaboScreenHeader(
            title: i18n.t("nav.review"),
            eyebrow: MicaboCalendar.dayLabel(Date())
        ) {
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

            Text(i18n.t("app.today.streakShort", ["count": "\(streak)"]))
                .font(MicaboFont.number(14, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(MicaboColor.caution)
        .padding(.vertical, 8)
        .padding(.horizontal, 13)
        .background(MicaboColor.cautionSoft, in: Capsule())
        .accessibilityLabel(i18n.t("app.today.streakAria", ["count": "\(streak)"]))
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
                    Text(load.dueCards.count > 1
                         ? i18n.t("app.today.dueMany")
                         : i18n.t("app.today.dueOne"))
                        .font(MicaboFont.ui(16, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(i18n.t("app.today.minutesCourses", [
                        "minutes": "\(load.estimatedMinutes)",
                        "courses": MicaboCopy.courses(max(load.coursesWithDue, 1))
                    ]))
                        .font(MicaboFont.ui(13, weight: .medium))
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
        var label = i18n.t("ios.dueReviewAria", ["cards": MicaboCopy.cards(load.dueCards.count)])
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
                        .font(MicaboFont.ui(12.5, weight: .medium))
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
                .font(MicaboFont.ui(12, weight: .regular))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    /// **Ce que la journée demande, cartes et mesures ensemble.**
    ///
    /// Un examen blanc ou un test de parcours est un travail du jour au même titre qu'un
    /// paquet de cartes à revoir, et il se lance d'ici. Les séparer aurait laissé l'étudiant
    /// finir ses cartes en croyant sa journée faite, puis découvrir la mesure ailleurs - ou
    /// pas du tout.
    ///
    /// Les mesures passent **en tête** : une fois les cartes revues, le tirage n'a plus la
    /// même valeur, puisqu'il porte sur ce qu'on vient de relire.
    @ViewBuilder
    private func dueCoursesSection(_ entries: [(course: Course, count: Int)]) -> some View {
        if !entries.isEmpty || !measuresToday.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(text: i18n.t("app.today.agenda"))

                MicaboRowGroup(
                    rows: measuresToday.map { measureRow($0) } + entries.map { entry in
                        MicaboRow.courseDue(entry.course, dueCount: entry.count) {
                            path.append(entry.course)
                        }
                    }
                )
            }
        }
    }

    /// La ligne d'une mesure : ce que c'est, pour quelle épreuve, et ce qu'elle coûte.
    private func measureRow(_ event: AgendaEvent) -> MicaboRow {
        let isMock = event.kind == .mock
        return MicaboRow(
            tile: MicaboTile(
                glyph: .symbol(isMock ? "doc.text" : "target"),
                background: isMock ? MicaboColor.accentSoft : MicaboColor.cautionSoft,
                tint: isMock ? MicaboColor.accent : MicaboColor.caution
            ),
            title: i18n.t(isMock ? "app.mock.blockTitle" : "app.parcours.blockTitle"),
            subtitle: "\(event.examName) · " + i18n.t(
                "app.today.mock",
                ["questions": "\(event.questionCount)", "minutes": "\(event.minutes)"]
            ),
            action: { starting = event }
        )
    }

    // MARK: - Examens

    /// **La prochaine épreuve a sa carte**, comme sur le site : le nom, le compte à rebours,
    /// et ce qu'on en sait aujourd'hui posé contre l'objectif. Les suivantes se lisent en
    /// dessous, sur une ligne chacune. Un appui ouvre la fiche de l'épreuve, où l'on trouve
    /// l'examen blanc et ce qui résiste ; le calendrier garde sa place dans la barre.
    /// **La section est toujours là**, même sans un seul cours.
    private func examSection(_ load: DayLoad) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                MicaboSectionCaption(text: i18n.t("app.today.nextExam"))
                Spacer(minLength: MicaboSpacing.xs)
                if !upcomingExams.isEmpty {
                    Button(i18n.t("app.today.seeExams")) {
                        openExams()
                    }
                    .font(MicaboFont.ui(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.accent)
                    .buttonStyle(MicaboPressableButtonStyle())
                }
            }

            if let next = nextExam {
                nextExamCard(next, mastery: load.examProgress[next.id] ?? 0)

                let others = Array(upcomingExams.dropFirst().prefix(3))
                if !others.isEmpty {
                    MicaboSectionCaption(text: i18n.t("app.today.otherExams"))
                        .padding(.top, MicaboSpacing.xs)
                    otherExams(others, load)
                }
            } else {
                Button {
                    openExams()
                } label: {
                    MicaboRow(
                        tile: MicaboTile(
                            glyph: .symbol("calendar"),
                            background: MicaboColor.surfaceMuted,
                            tint: MicaboColor.inkSecondary
                        ),
                        title: i18n.t("app.today.planExam"),
                        subtitle: examEmptySubtitle,
                        accessory: .chevron
                    )
                }
                .buttonStyle(MicaboRowButtonStyle())
                .micaboGroup()
            }
        }
    }

    /// Le nom, le compte à rebours, et la jauge : ce qu'on sait contre ce qu'on vise.
    private func nextExamCard(_ exam: Exam, mastery: Int) -> some View {
        let target = TargetScore.percent(from: exam.targetScore)

        return Button {
            path.append(exam)
        } label: {
            VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: MicaboSpacing.sm) {
                    Text(exam.name)
                        .font(MicaboFont.ui(16, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: MicaboSpacing.xs)
                    MicaboBadge(text: exam.countdownLabel(), tone: exam.daysRemaining() <= 3 ? .warm : .neutral)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(mastery)")
                            .font(MicaboFont.number(30, weight: .bold))
                            .foregroundStyle(MicaboColor.ink)
                            .monospacedDigit()
                        Text("%")
                            .font(MicaboFont.ui(15, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                    }
                    Text(i18n.t("app.chart.readiness.now"))
                        .font(MicaboFont.micro)
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(MicaboColor.surfaceMuted)
                        Capsule()
                            .fill(MicaboColor.accent)
                            .frame(width: proxy.size.width * CGFloat(max(2, mastery)) / 100)
                        Rectangle()
                            .fill(MicaboColor.ink)
                            .frame(width: 2, height: 12)
                            .offset(x: proxy.size.width * CGFloat(target) / 100 - 1)
                    }
                }
                .frame(height: 8)

                Text(i18n.t("app.chart.readiness.target", ["percent": "\(target)"]))
                    .font(MicaboFont.micro)
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .soft))
        .micaboGroup()
        .accessibilityLabel("\(exam.name), \(exam.countdownLabel()). \(mastery) %, \(i18n.t("app.chart.readiness.target", ["percent": "\(target)"]))")
    }

    private func otherExams(_ exams: [Exam], _ load: DayLoad) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(exams.enumerated()), id: \.element.id) { index, exam in
                Button {
                    path.append(exam)
                } label: {
                    MicaboRow(
                        tile: MicaboTile.exam(exam.date),
                        title: exam.name,
                        subtitle: i18n.t("app.today.known", ["percent": "\(load.examProgress[exam.id] ?? 0)"]),
                        accessory: .badge(exam.countdownLabel(), .neutral)
                    )
                }
                .buttonStyle(MicaboRowButtonStyle())

                if index < exams.count - 1 {
                    MicaboHairline(inset: 72)
                }
            }
        }
        .micaboGroup()
    }

    private func openExams() {
        router?.selection = .exams
    }

    private var examEmptySubtitle: String {
        (load?.totalCards ?? 0) == 0
            ? i18n.t("app.today.whenYouHaveCards")
            : i18n.t("app.today.addDate")
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
            Segment(label: i18n.t("app.today.segReview"), color: MicaboColor.caution, count: load.reviewCount),
            Segment(label: i18n.t("app.today.segLearning"), color: MicaboColor.accent, count: load.learningCount),
            Segment(label: i18n.t("app.today.segNew"), color: MicaboColor.inkTertiary, count: load.newCount)
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
    private func restState(_ load: DayLoad) -> some View {
        if load.totalCards == 0 {
            MicaboEmptyState(
                systemImage: "rectangle.on.rectangle.angled",
                title: i18n.t("app.home.empty.noCardsTitle"),
                message: i18n.t("app.home.empty.noCardsBody"),
                actionTitle: i18n.t("ios.importAction")
            ) {
                requestImport()
            }
        } else {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                doneState

                if !load.nextDue.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        MicaboSectionCaption(text: i18n.t("app.today.nextDue"))

                        MicaboRowGroup(
                            rows: load.nextDue.map { entry in
                                MicaboRow(
                                    tile: MicaboTile.course(entry.course),
                                    title: entry.course.title,
                                    subtitle: i18n.t("app.today.inDelay", [
                                        "delay": SM2Scheduler.format(delay: entry.due.timeIntervalSinceNow)
                                    ]),
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
        reviewDoneCard(subtitle: i18n.t("app.today.dayDone"))
    }

    /// Le tick vert est le sujet : sans lui, « C'est fait » se lisait comme une légende.
    private func reviewDoneCard(subtitle: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(MicaboColor.accentVivid)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(i18n.t("app.today.doneTitle"))
                    .font(MicaboFont.ui(22, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)

                Text(subtitle)
                    .font(MicaboFont.ui(14.5, weight: .regular))
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
        .accessibilityLabel("\(i18n.t("app.today.doneTitle")). \(subtitle)")
    }

    // MARK: - Session

    /// Un seul bouton de session dans l'app, et il garde son nom d'un écran à l'autre.
    private var hasSessionButton: Bool {
        (load?.totalCards ?? 0) > 0
    }

    private func sessionButtonTitle(_ load: DayLoad) -> String {
        if !load.dueCards.isEmpty { return MicaboCopy.reviewButton(count: load.dueCards.count) }
        if load.heldBackNewCards > 0 { return i18n.t("app.review.verb") }
        return MicaboCopy.practiceReview()
    }

    private var canPractice: Bool { pro?.canPractice ?? true }

    /// Réviser ce qui est dû reste gratuit. Prendre de l'avance sur tout un paquet, non :
    /// c'est ce qu'on fait la veille d'un partiel, et c'est ce que Pro ouvre.
    private func startSession() {
        let load = load ?? .empty
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
            activeImport = kind
        }
    }
}
