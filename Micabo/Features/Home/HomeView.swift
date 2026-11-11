import SwiftData
import SwiftUI

/// **Home**, dans l'ordre où un élève la lit (`docs/refonte-knowunity.md` § 1). Elle n'a pas la
/// même tête selon qu'il a déjà ses leçons ou non.
///
/// **L'élève qui a ses leçons** vient réviser : la rangée du haut ; le bonjour et l'objectif du
/// jour ; **« Ton plan du jour »** sur une seule carte claire — la ligne méta du prochain
/// examen, **la** chose à faire maintenant (la séance du calendrier, la leçon en cours ou les
/// cartes dues) et un seul grand bouton bleu, Mika qui dépasse de son bord ; juste dessous, la
/// barre « Nouvelle leçon » et ses raccourcis (scanner, quiz éclair) ; ce qui reste à l'agenda
/// d'aujourd'hui ; ses leçons récentes. Le minuteur est l'onglet Concentration, la ligue
/// l'éclair de la rangée du haut : Home ne les répète pas.
///
/// **L'élève tout neuf** vient écrire sa première leçon, celle qui est offerte : Mika, sur le
/// papier de la page, parle dans sa bulle au-dessus de la barre « comme une conversation »,
/// le scanner dessous, puis « Comment ça marche ».
///
/// La barre, dans les deux cas, passe par la même porte du gratuit (`send`, `tapImport`).
///
/// **Un appui à côté du champ range le clavier.** La rangée du haut, Mika et tout le vide
/// entre les blocs le rendent ; les boutons gardent leur appui, parce qu'un geste posé sur un
/// parent passe après ceux de ses enfants. Le geste n'est jamais posé sur la barre elle-même :
/// un appui dans le champ doit l'ouvrir, pas le refermer aussitôt.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(TabRouter.self) private var router: TabRouter?
    @Query(sort: \Course.createdAt, order: .reverse) private var courses: [Course]
    /// Ce que le plan du jour lit du calendrier : relu quand l'un d'eux change.
    @Query private var events: [CalendarEvent]
    @Query(sort: \Exam.date) private var exams: [Exam]
    @Query private var tasks: [StudyTask]

    @State private var path = NavigationPath()
    @State private var composer = LessonComposer()
    @State private var importRequest: LessonComposer.Kind?
    @State private var creating = false
    @State private var paywall: PaywallTrigger?
    @State private var showsStreak = false
    /// La ligue de la semaine (`docs/refonte-knowunity.md` § 3) : la pastille XP et l'outil.
    @State private var showsLeague = false
    @State private var showsScanner = false
    /// « Corriger un texte » (lot 7), en plein écran comme le scanner.
    @State private var showsWriting = false
    @State private var showsDueReview = false
    @State private var quickQuizCourse: Course?
    /// La feuille du « + » : les supports en grandes tuiles.
    @State private var showsSources = false
    /// Le support choisi dans la feuille, ouvert une fois la feuille refermée : deux feuilles
    /// ne se présentent pas en même temps.
    @State private var pendingImport: LessonComposer.Kind?
    /// Les blocs sont entrés : l'entrée ne se rejoue pas à chaque retour sur l'onglet.
    @State private var appeared = false
    @State private var streak = StudyStreak.status()
    /// L'agenda d'aujourd'hui (`StudyPlan.today`) et le prochain examen, relus à l'arrivée.
    @State private var agenda: [AgendaItem] = []
    @State private var nextExam: HomeExam?
    @State private var now = Date()
    /// Une séance de révision du calendrier, lancée d'ici comme du calendrier.
    @State private var focusPlan: FocusPlan?
    @State private var editingExam: ExamEditTarget?
    @FocusState private var focused: Bool

    private var isPro: Bool { pro?.isPro ?? true }

    /// La leçon offerte n'a pas encore servi : un import peut l'écrire (§ 7).
    private var freeLessonLeft: Bool {
        !isPro && !LessonAllowance.hasUsedFreeLesson(courses: courses)
    }

    private var lessons: [Course] { courses.filter { $0.isLesson && $0.source != .deck } }

    var body: some View {
        presentations
            .task(id: planKey) { refreshPlan() }
            // Le journal des cartes rejoint la série une fois : un ancien compte retrouve la
            // sienne dans la pastille dès l'ouverture.
            .task { StudyStreak.adoptReviewHistoryIfNeeded(in: modelContext) }
            .onAppear {
                refreshStreak()
                refreshPlan()
                guard !appeared else { return }
                Haptics.prepare()
                DispatchQueue.main.async { appeared = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: .micaboStreakDidChange)) { _ in refreshStreak() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                refreshStreak()
                refreshPlan()
            }
            .reportsNavigationDepth(for: .today, depth: path.count)
            .returnsHome(path: $path)
    }

    // MARK: La page

    private var page: some View {
        let resume = ResumeTarget.pick(from: courses)
        let day = today(resume: resume)
        let name = HomeGreeting.firstName(OnboardingPreferences.displayName)
        let moment = HomeGreeting.moment(hour: Calendar.current.component(.hour, from: now))
        return ScrollView {
            HomeScreen(
                composer: composer,
                focused: $focused,
                isPro: isPro,
                name: name,
                hello: HomeGreeting.hello(name: name, moment: moment),
                greeting: HomeGreeting.lines(name: name, moment: moment, dueCount: day.dueCount),
                day: day,
                resume: resume,
                plan: HomePlan(
                    exam: nextExam,
                    agenda: HomePlan.upcoming(agenda, now: now, excluding: day.session),
                    lessons: HomeLessonCard.recent(courses)
                ),
                motion: HomeMotion(still: false, reduceMotion: reduceMotion),
                appeared: appeared,
                actions: actions(day: day, resume: resume?.0)
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .background(HomePalette.canvas.ignoresSafeArea())
        .tabBarClearance()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var navigation: some View {
        NavigationStack(path: $path) {
            page
                .navigationDestination(for: Course.self) { course in
                    LessonPathView(course: course)
                }
                .lessonImportPickers(composer, request: $importRequest)
                .fullScreenCover(isPresented: $creating) {
                    LessonCreationFlow(composer: composer, sendsAsFreeLesson: LessonAllowance.sendsAsFreeLesson(isPro: isPro, source: composer.source, courses: courses)) { course in
                        creating = false
                        composer.reset()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { path.append(course) }
                    } onCancel: {
                        creating = false
                    }
                }
                .micaboPaywall($paywall)
        }
    }

    /// Le compilateur type mal d'un seul tenant la pile, les feuilles et les couvertures :
    /// chaque morceau se type de son côté, comme dans `CalendarView`.
    private var sheets: some View {
        navigation
            .sheet(isPresented: $showsSources, onDismiss: openPendingImport) {
                HomeSourcesSheet(isPro: isPro, freeLessonLeft: freeLessonLeft, enabled: composer.hasRoom) { kind in
                    pendingImport = kind
                    showsSources = false
                }
            }
            .sheet(isPresented: $showsStreak) {
                StreakSheet(onStudy: study)
            }
            .sheet(isPresented: $showsLeague) {
                LeagueSheet()
            }
            .sheet(item: $editingExam, onDismiss: refreshPlan) { target in
                ExamEditSheet(target: target, lessons: lessons)
            }
    }

    /// Les parcours — réviser ses cartes, le quiz éclair, une séance, le scanner — en plein
    /// écran : un glissement ne les referme pas en plein milieu, leur croix le fait.
    private var presentations: some View {
        sheets
            .fullScreenCover(isPresented: $showsDueReview, onDismiss: refreshPlan) {
                DueCardsReview(courses: DueReview.courses(courses))
            }
            .fullScreenCover(item: $quickQuizCourse) { course in
                QuickQuizSheet(course: course)
            }
            .fullScreenCover(item: $focusPlan, onDismiss: refreshPlan) { plan in
                FocusTimerView(plan: plan)
            }
            .fullScreenCover(isPresented: $showsScanner) {
                ScanExerciseView()
            }
            .fullScreenCover(isPresented: $showsWriting) {
                WritingCoachView()
            }
    }

    // MARK: Ce que Home lit

    /// Ce que l'app sait de la journée, pour le plan du jour.
    private func today(resume: (Course, ResumeTarget)?) -> HomeDay {
        let calendar = Calendar.current
        var day = HomeDay()
        day.hasCourses = !courses.isEmpty
        day.studiedToday = streak.studiedToday
        for course in courses {
            day.dueCount += DueReview.dueCount(of: course, now: now)
            day.reviewedToday += course.cards.filter { card in
                card.lastReviewedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
            }.count
        }
        if let resume, let number = resume.1.circleNumber {
            let (course, target) = resume
            day.lessonTitle = target.title
            day.lessonCircle = L10n.t("lesson.path.circleNumber", locale: .resolved(), vars: ["n": String(number)])
            let finishedToday = course.progress.finishedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
            let openedToday = course.lastOpenedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
            day.lessonAdvancedToday = finishedToday || (openedToday && streak.studiedToday)
        }
        let examNames = Dictionary(exams.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        day.session = HomeSession.next(in: agenda, now: now, examNames: examNames)
        return day
    }

    /// Ce qui fait relire le plan : une séance cochée ou déplacée, un examen ajouté, une tâche
    /// faite, une leçon de plus.
    private var planKey: String {
        let eventStamp = events.map(\.updatedAt).max()?.timeIntervalSince1970 ?? 0
        let examStamp = exams.map(\.updatedAt).max()?.timeIntervalSince1970 ?? 0
        let done = tasks.filter(\.isDone).count
        return "\(courses.count)-\(events.count)-\(eventStamp)-\(exams.count)-\(examStamp)-\(tasks.count)-\(done)"
    }

    /// **Le plan du jour, relu** : l'agenda d'aujourd'hui (`StudyPlan.today`), le prochain
    /// examen (`NextExam.current`) et sa préparation. Rien pour l'élève tout neuf : sa Home
    /// n'en montre rien.
    private func refreshPlan() {
        let current = Date()
        now = current
        guard !courses.isEmpty else {
            agenda = []
            nextExam = nil
            return
        }
        agenda = StudyPlan.today(in: modelContext, now: current)
        guard let exam = NextExam.current(in: modelContext, now: current) else {
            nextExam = nil
            return
        }
        let cards = ExamRepository.cards(of: exam, in: modelContext)
        let readiness = cards.isEmpty
            ? nil
            : ExamReadiness.masteryPercent(of: cards, logs: ExamReadiness.recentLogsByCard(in: modelContext, now: current), now: current)
        nextExam = HomeExam(name: exam.name, daysLeft: max(0, exam.daysRemaining(from: current)), readiness: readiness)
    }

    // MARK: Les gestes

    private func actions(day: HomeDay, resume: Course?) -> HomeActions {
        var profile: (() -> Void)?
        if let router {
            profile = {
                dismissKeyboard()
                router.selection = .profile
            }
        }
        return HomeActions(
            profile: profile,
            pro: {
                dismissKeyboard()
                paywall = .upgrade
            },
            league: {
                dismissKeyboard()
                showsLeague = true
            },
            streak: {
                dismissKeyboard()
                showsStreak = true
            },
            sources: {
                dismissKeyboard()
                showsSources = true
            },
            send: send,
            step: { step, slot in
                dismissKeyboard()
                Analytics.track(.homePlanTapped, [
                    "step": .text(step.rawValue),
                    "slot": .text(slot.rawValue),
                    "exam": .flag(nextExam != nil),
                ])
                switch step {
                case .session: if let session = day.session { start(session) }
                case .cards: showsDueReview = true
                case .lesson: if let resume { path.append(resume) } else { focused = true }
                case .create: focused = true
                }
            },
            tool: { tool in open(tool, resume: resume) },
            exam: {
                dismissKeyboard()
                router?.showCalendar()
            },
            addExam: {
                dismissKeyboard()
                editingExam = .new
            },
            calendar: {
                dismissKeyboard()
                router?.showCalendar(day: now)
            },
            agendaTap: { item in
                dismissKeyboard()
                if item.kind == .task {
                    toggleTask(item)
                } else {
                    router?.showCalendar(day: now)
                }
            },
            agendaStart: { item in
                dismissKeyboard()
                start(item)
            },
            agendaToggle: toggleTask,
            lesson: { id in
                dismissKeyboard()
                if let course = courses.first(where: { $0.id == id }) { path.append(course) }
            },
            allLessons: {
                dismissKeyboard()
                router?.selection = .decks
            },
            dismissKeyboard: dismissKeyboard
        )
    }

    /// La séance du plan, lancée comme le calendrier la lance (`FocusPlan.revision`).
    private func start(_ session: HomeSession) {
        let course = courses.first { $0.id == session.courseID }
        focusPlan = .revision(eventID: session.eventID, startMinute: session.startMinute, endMinute: session.endMinute, courseID: course?.id, courseTitle: course?.title)
    }

    /// Le ▶ d'une ligne de l'agenda : une séance de révision part d'ici ; le reste s'ouvre dans
    /// le calendrier, où vivent l'examen blanc et ses réglages.
    private func start(_ item: AgendaItem) {
        guard item.kind == .revision, let startMinute = item.startMinute, let endMinute = item.endMinute else {
            router?.showCalendar(day: now)
            return
        }
        let course = courses.first { $0.id == item.courseID }
        focusPlan = .revision(eventID: item.eventID, startMinute: startMinute, endMinute: endMinute, courseID: course?.id, courseTitle: course?.title)
    }

    /// Une tâche à rendre, cochée d'ici comme dans Concentration.
    private func toggleTask(_ item: AgendaItem) {
        guard let task = tasks.first(where: { $0.id == item.taskID }) else { return }
        withAnimation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion)) {
            task.isDone.toggle()
            task.doneAt = task.isDone ? Date() : nil
        }
        try? modelContext.save()
        if task.isDone {
            Haptics.success()
            Analytics.track(.taskDone)
        }
        refreshPlan()
    }

    private func refreshStreak() {
        let next = StudyStreak.status()
        guard next != streak else { return }
        withAnimation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion)) { streak = next }
    }

    private func dismissKeyboard() {
        focused = false
    }

    /// « Faire une leçon », depuis la feuille de la série : la leçon en cours s'il y en a une,
    /// sinon la barre, prête à écrire.
    private func study() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if let resume = ResumeTarget.pick(from: courses) {
                path.append(resume.0)
            } else {
                focused = true
            }
        }
    }

    /// Un import s'ouvre toujours : la lecture se fait sur l'appareil, et c'est l'écriture de la
    /// leçon qui passe par la porte du gratuit (`LessonAllowance.locksImport`, `sendRoute`).
    private func tapImport(_ kind: LessonComposer.Kind) {
        if LessonAllowance.locksImport(kind, isPro: isPro, freeLessonLeft: freeLessonLeft) {
            focused = false
            paywall = .generateCourse
            return
        }
        importRequest = kind
    }

    /// La feuille du « + » est refermée : le support choisi s'ouvre maintenant.
    private func openPendingImport() {
        guard let kind = pendingImport else { return }
        pendingImport = nil
        tapImport(kind)
    }

    /// Un outil, depuis son raccourci.
    private func open(_ tool: HomeTool, resume: Course?) {
        dismissKeyboard()
        Analytics.track(.homeToolOpened, ["tool": .text(tool.analyticsName)])
        switch tool {
        case .writing:
            // Toujours ouvert, comme le scanner : la porte de Mika vient à la demande de
            // relecture, une fois le texte à l'écran (`WritingSession`).
            showsWriting = true
        case .scan:
            // Le scanner s'ouvre toujours : la lecture de l'énoncé se fait sur l'appareil, et
            // l'historique comme les fils de Mika restent à l'élève. La porte de Mika vient à la
            // demande de solution, une fois l'énoncé reconnu à l'écran (`SolverSession`).
            showsScanner = true
        case .quiz:
            if let resume {
                quickQuizCourse = resume
            } else {
                focused = true
            }
        }
    }

    private func send() {
        guard composer.canSend else { return }
        if let trigger = LessonAllowance.immediatePaywall(isPro: isPro, source: composer.source, courses: courses) {
            focused = false
            paywall = trigger
            return
        }
        focused = false
        creating = true
    }
}

// MARK: - L'écran

/// Les gestes de Home, pour que l'écran se dessine sans rien savoir de la navigation : les
/// rendus de la CI le posent avec des gestes vides.
struct HomeActions {
    var profile: (() -> Void)?
    var pro: () -> Void = {}
    var league: () -> Void = {}
    var streak: () -> Void = {}
    var sources: () -> Void = {}
    var send: () -> Void = {}
    var step: (HomeDay.Step, HomeSlot) -> Void = { _, _ in }
    var tool: (HomeTool) -> Void = { _ in }
    var exam: () -> Void = {}
    var addExam: () -> Void = {}
    var calendar: () -> Void = {}
    var agendaTap: (AgendaItem) -> Void = { _ in }
    var agendaStart: (AgendaItem) -> Void = { _ in }
    var agendaToggle: (AgendaItem) -> Void = { _ in }
    var lesson: (UUID) -> Void = { _ in }
    var allLessons: () -> Void = {}
    var dismissKeyboard: () -> Void = {}
}

/// **Tout Home, de haut en bas**, sans défilement ni navigation : `HomeView` le pose dans son
/// `ScrollView`, les rendus le dessinent tel quel.
struct HomeScreen: View {
    let composer: LessonComposer
    var focused: FocusState<Bool>.Binding
    let isPro: Bool
    let name: String?
    /// Le bonjour court du plan du jour (`HomeGreeting.hello`).
    let hello: String
    /// Les phrases de la bulle de Mika, pour l'élève tout neuf (`HomeGreeting.lines`).
    let greeting: [String]
    let day: HomeDay
    let resume: (Course, ResumeTarget)?
    let plan: HomePlan
    let motion: HomeMotion
    let appeared: Bool
    var streakPreview: StudyStreak.Status?
    let actions: HomeActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeTopBar(
                name: name,
                isPro: isPro,
                onProfile: actions.profile,
                onPro: actions.pro,
                onLeague: actions.league,
                onStreak: actions.streak,
                streakPreview: streakPreview
            )
            .homeEntrance(0, shown: appeared, motion: motion)

            if day.hasCourses {
                returning
            } else {
                newcomer
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Le vide entre les blocs : rien n'y est touchable, l'appui tombe sur ce fond.
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: actions.dismissKeyboard)
        )
    }

    /// L'élève qui a ses leçons : son plan d'abord, écrire ensuite.
    @ViewBuilder
    private var returning: some View {
        HomeGreetingRow(title: hello, motion: motion)
            .padding(.top, 16)
            .homeEntrance(1, shown: appeared, motion: motion)

        HomePlanHero(
            day: day,
            resume: resume,
            exam: plan.exam,
            motion: motion,
            onStep: actions.step,
            onExam: actions.exam,
            onAddExam: actions.addExam
        )
        .padding(.top, 16)
        .homeEntrance(2, shown: appeared, motion: motion)

        // Créer vient juste après la séance : c'est ce qui fait revenir (charte du lot 6).
        HomeCreateSection(
            composer: composer,
            focused: focused,
            tools: HomeTool.available(hasLesson: resume != nil),
            onSend: actions.send,
            onSources: actions.sources,
            onTool: actions.tool
        )
        .padding(.top, 24)
        .homeEntrance(3, shown: appeared, motion: motion)

        if !plan.agenda.isEmpty {
            HomeAgendaSection(
                items: plan.agenda,
                onTap: actions.agendaTap,
                onStart: actions.agendaStart,
                onToggle: actions.agendaToggle,
                onCalendar: actions.calendar
            )
            .padding(.top, 32)
            .homeEntrance(4, shown: appeared, motion: motion)
        }

        if !plan.lessons.isEmpty {
            HomeLessonsSection(lessons: plan.lessons, onOpen: actions.lesson, onAll: actions.allLessons)
                .padding(.top, 32)
                .homeEntrance(5, shown: appeared, motion: motion)
        }
    }

    /// L'élève tout neuf : écrire sa première leçon, la leçon offerte, et le scanner sous la
    /// main.
    @ViewBuilder
    private var newcomer: some View {
        HomeHeroCard(
            composer: composer,
            focused: focused,
            lines: greeting,
            motion: motion,
            onSend: actions.send,
            onSources: actions.sources,
            onDismissKeyboard: actions.dismissKeyboard
        )
        .padding(.top, 16)
        .homeEntrance(1, shown: appeared, motion: motion)

        HomeQuickActions(tools: HomeTool.available(hasLesson: false), onTool: actions.tool)
            .padding(.top, 12)
            .homeEntrance(2, shown: appeared, motion: motion)

        HomeHowItWorks()
            .padding(.top, 24)
            .homeEntrance(3, shown: appeared, motion: motion)
    }
}

// MARK: - Les supports

// La feuille du « + » (`HomeSourcesSheet`) vit avec les supports, dans
// `Features/Import/SourcesSheet.swift` (`docs/supports.md`).
