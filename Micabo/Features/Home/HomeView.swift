import SwiftData
import SwiftUI

/// **Home**, dans l'ordre où un élève la lit (`docs/refonte-knowunity.md` § 1). Elle n'a pas la
/// même tête selon qu'il a déjà ses leçons ou non.
///
/// **L'élève qui a ses leçons** vient réviser : la rangée du haut ; le bonjour et l'objectif du
/// jour ; **« Ton plan du jour »** sur une carte claire — le prochain examen, **la** chose à
/// faire maintenant (la séance du calendrier, la leçon en cours ou les cartes dues) et un seul
/// grand bouton bleu, Mika qui dépasse de son bord ; ce qui reste à l'agenda d'aujourd'hui ;
/// ses leçons récentes ; la barre « Nouvelle leçon », en second ; les outils.
///
/// **L'élève tout neuf** vient écrire sa première leçon, celle qui est offerte : Mika, sur le
/// papier de la page, parle dans sa bulle au-dessus de la barre « comme une conversation »,
/// puis « Comment ça marche » et les outils.
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
    @State private var showsTimer = false
    @State private var showsScanner = false
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
            .sheet(isPresented: $showsDueReview, onDismiss: refreshPlan) {
                DueCardsReview(courses: DueReview.courses(courses))
            }
            .sheet(item: $quickQuizCourse) { course in
                QuickQuizSheet(course: course)
            }
            .sheet(item: $editingExam, onDismiss: refreshPlan) { target in
                ExamEditSheet(target: target, lessons: lessons)
            }
    }

    private var presentations: some View {
        sheets
            .fullScreenCover(isPresented: $showsTimer) {
                FocusTimerView()
            }
            .fullScreenCover(item: $focusPlan, onDismiss: refreshPlan) { plan in
                FocusTimerView(plan: plan)
            }
            .fullScreenCover(isPresented: $showsScanner) {
                ScanExerciseView()
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
        withAnimation(.spring(duration: 0.3)) {
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
        withAnimation(.spring(duration: 0.4)) { streak = next }
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
        switch tool {
        case .scan:
            // La porte de Mika avant l'appareil photo : scanner pour tomber sur le paywall
            // serait un geste pour rien.
            if MikaQuota().gate(isPro: isPro) == .paywall {
                paywall = .mika
            } else {
                showsScanner = true
            }
        case .quiz:
            if let resume {
                quickQuizCourse = resume
            } else {
                focused = true
            }
        case .timer:
            // L'onglet Concentration prépare la séance ; le minuteur seul reste pour un écran
            // sans barre d'onglets.
            if let router {
                router.requestFocusSession()
            } else {
                showsTimer = true
            }
        case .league:
            showsLeague = true
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
            .padding(.top, 18)
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
        .padding(.top, 14)
        .homeEntrance(2, shown: appeared, motion: motion)

        if !plan.agenda.isEmpty {
            HomeAgendaSection(
                items: plan.agenda,
                onTap: actions.agendaTap,
                onStart: actions.agendaStart,
                onToggle: actions.agendaToggle,
                onCalendar: actions.calendar
            )
            .padding(.top, 26)
            .homeEntrance(3, shown: appeared, motion: motion)
        }

        if !plan.lessons.isEmpty {
            HomeLessonsSection(lessons: plan.lessons, onOpen: actions.lesson, onAll: actions.allLessons)
                .padding(.top, 26)
                .homeEntrance(4, shown: appeared, motion: motion)
        }

        HomeCreateSection(composer: composer, focused: focused, onSend: actions.send, onSources: actions.sources)
            .padding(.top, 26)
            .homeEntrance(5, shown: appeared, motion: motion)

        HomeToolsCard(onTool: actions.tool)
            .padding(.top, 16)
            .homeEntrance(6, shown: appeared, motion: motion)
    }

    /// L'élève tout neuf : écrire sa première leçon, la leçon offerte.
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
        .padding(.top, 14)
        .homeEntrance(1, shown: appeared, motion: motion)

        HomeHowItWorks()
            .padding(.top, 16)
            .homeEntrance(2, shown: appeared, motion: motion)

        HomeToolsCard(onTool: actions.tool)
            .padding(.top, 16)
            .homeEntrance(3, shown: appeared, motion: motion)
    }
}

// MARK: - Les supports

/// **La feuille du « + »** : tous les supports en grandes tuiles colorées, et la leçon offerte
/// rappelée tant qu'elle reste. Une tuile referme la feuille ; le support s'ouvre ensuite
/// (`HomeView.openPendingImport`), par la même porte que les raccourcis de la barre.
struct HomeSourcesSheet: View {
    let isPro: Bool
    var freeLessonLeft = false
    var enabled = true
    let onPick: (LessonComposer.Kind) -> Void

    @Environment(\.homeStill) private var still

    var body: some View {
        Group {
            if still {
                content
            } else {
                ScrollView { content }
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(HomePalette.canvas.ignoresSafeArea())
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MicaboRadius.sheet)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                MikaMascot(mood: .happy, size: 64, frame: .circle)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("ios.home2.sources.title", locale: .resolved()))
                        .font(MicaboFont.ui(24, weight: .black))
                        .foregroundStyle(HomePalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.t("ios.home2.sources.sub", locale: .resolved()))
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(HomePalette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if freeLessonLeft {
                HStack(spacing: 6) {
                    Text("🎁")
                    Text(L10n.t("ios.home2.sources.free", locale: .resolved()))
                        .font(MicaboFont.ui(14, weight: .heavy))
                }
                .foregroundStyle(HomePalette.done)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(HomePalette.doneSoft, in: Capsule())
            }
            VStack(spacing: 12) {
                // Les deux tuiles d'une rangée ont la hauteur de la plus haute.
                HStack(spacing: 12) {
                    tile(.pdf)
                    tile(.photo)
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    tile(.youtube)
                    tile(.audio)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            HomeSourceTile(kind: .text, locked: false, enabled: enabled, wide: true) { onPick(.text) }
            if !enabled {
                Text(L10n.t("lesson.home.supportsFull", locale: .resolved(), vars: ["n": String(LessonComposer.maximumSupports)]))
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(HomePalette.inkSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 20)
    }

    private func tile(_ kind: LessonComposer.Kind) -> some View {
        HomeSourceTile(kind: kind, locked: locked(kind), enabled: enabled, wide: false) { onPick(kind) }
    }

    private func locked(_ kind: LessonComposer.Kind) -> Bool {
        LessonAllowance.locksImport(kind, isPro: isPro, freeLessonLeft: freeLessonLeft)
    }
}

/// Une grande tuile de support, comme les outils de Home : une carte de la page, l'icône 3D
/// sur sa pastille de couleur, le nom et ce qu'on y met.
struct HomeSourceTile: View {
    let kind: LessonComposer.Kind
    var locked = false
    var enabled = true
    var wide = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if wide {
                    HStack(spacing: 14) {
                        icon
                        labels
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        icon
                        labels
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 128, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(14)
            .homeCard(radius: MicaboStage.tileRadius)
            .overlay(alignment: .topTrailing) {
                if locked {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LessonTone.yellow.ink)
                        .padding(6)
                        .background(LessonTone.yellow.pale, in: Circle())
                        .padding(10)
                        .accessibilityLabel(Text("Pro"))
                }
            }
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(HomePressStyle(scale: 0.96, feedback: .soft))
        .disabled(!enabled)
    }

    private var icon: some View {
        MicaboIconView(icon: kind.icon, size: 32)
            .frame(width: 52, height: 52)
            .background(Self.tone(kind).pale, in: Circle())
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.t(kind.titleKey, locale: .resolved()))
                .font(MicaboFont.ui(17, weight: .black))
                .foregroundStyle(HomePalette.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t(kind.titleKey + "Sub", locale: .resolved()))
                .font(MicaboFont.ui(13, weight: .semibold))
                .foregroundStyle(HomePalette.inkSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// La pastille de chaque support, dans les tons de l'app.
    static func tone(_ kind: LessonComposer.Kind) -> LessonTone {
        switch kind {
        case .pdf: .blue
        case .photo: .pink
        case .youtube: .yellow
        case .audio: .mint
        case .text: .lilac
        }
    }
}
