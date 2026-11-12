import SwiftData
import SwiftUI

/// **Home** (lot 10, HOME.md § 1) : elle ne défile pas et ne dit qu'une chose.
///
/// De haut en bas : l'en-tête (« Passer en PRO », l'XP, la série) ; la pastille jaune de
/// l'examen, qui mène au Calendrier ; Mika ; **une** phrase tirée du plan du jour et **une**
/// action (`HomeBoard`) ; en bas, fixées au-dessus des onglets, les puces d'outils — « Focus »
/// d'abord — et la barre de saisie (`HomeDock`).
///
/// Ce qui a quitté la Home reste à un geste : la carte de séance est devenue la phrase et son
/// action ; les leçons ont leur onglet ; l'agenda du jour, le Calendrier (la pastille d'examen
/// y mène) ; la Concentration, la puce « Focus » et son onglet ; le Profil, son onglet.
///
/// **La leçon s'écrit ici** (`LessonGeneration`) : une fois les deux questions posées
/// (`LessonCreationFlow`), la Home dit « J'écris ta leçon… », la jauge à la place de l'action,
/// et l'élève garde la main sur le reste de l'app. La leçon arrivée s'ouvre sur son chemin.
///
/// **Rien de lourd ne se calcule au dessin** : la journée (cartes dues, leçon en cours, séance
/// du calendrier, prochain examen) est lue quand quelque chose change (`refreshPlan`) et gardée
/// (`HomeSnapshot`) ; `body` ne fait que la mettre en phrase.
///
/// La barre passe par la même porte du gratuit qu'avant (`send`, `tapImport`).
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(TabRouter.self) private var router: TabRouter?
    /// Optionnel : le banc d'essai pose la Home sans lui, et rien ne s'y écrit.
    @Environment(LessonBuilder.self) private var builder: LessonBuilder?
    @Environment(XPStore.self) private var injectedXP: XPStore?
    @Query(sort: \Course.createdAt, order: .reverse) private var courses: [Course]
    /// Ce que le plan du jour lit du calendrier : relu quand l'un d'eux change.
    @Query private var events: [CalendarEvent]
    @Query(sort: \Exam.date) private var exams: [Exam]
    @Query private var tasks: [StudyTask]

    @State private var path = NavigationPath()
    @State private var composer = LessonComposer()
    /// La leçon qui s'écrit : elle vit autant que la Home.
    @State private var generation = LessonGeneration()
    @State private var connectivity = HomeConnectivity()
    @State private var importRequest: LessonComposer.Kind?
    /// Les deux questions d'avant l'écriture (« As-tu un examen ? »).
    @State private var creating = false
    @State private var paywall: PaywallTrigger?
    @State private var showsStreak = false
    /// « Faire une leçon », choisi dans la feuille de la série : fait une fois la feuille refermée.
    @State private var studiesAfterStreak = false
    /// La ligue de la semaine : l'XP de l'en-tête y mène.
    @State private var showsLeague = false
    @State private var showsScanner = false
    /// « Corriger un texte », en plein écran comme le scanner.
    @State private var showsWriting = false
    @State private var showsDueReview = false
    @State private var quickQuizCourse: Course?
    @State private var mock: MockExamStart?
    /// La feuille du « + » : les sources en grandes tuiles.
    @State private var showsSources = false
    /// La source choisie dans la feuille, ouverte une fois la feuille refermée : deux feuilles
    /// ne se présentent pas en même temps.
    @State private var pendingImport: LessonComposer.Kind?
    @State private var streak = StudyStreak.status()
    /// La journée, telle qu'elle a été lue la dernière fois.
    @State private var snapshot = HomeSnapshot()
    /// Une leçon lue qui attend Pro : l'aperçu verrouillé a été refermé sans abonnement.
    @State private var locked: HomeLockedLesson?
    /// Mika a fait coucou : il ne le refait pas à chaque retour sur l'onglet.
    @State private var greeted = false
    /// Une séance de révision ou de Concentration, lancée d'ici.
    @State private var focusPlan: FocusPlan?
    @State private var editingExam: ExamEditTarget?
    /// Les demandes de nouvelle leçon venues de l'onglet Leçons, déjà servies.
    @State private var handledCreationRequests = 0
    @FocusState private var focused: Bool

    private var isPro: Bool { pro?.isPro ?? true }
    private var xp: XPStore { injectedXP ?? .shared }

    /// La leçon offerte n'a pas encore servi : un import peut l'écrire.
    private var freeLessonLeft: Bool {
        !isPro && !LessonAllowance.hasUsedFreeLesson(courses: courses)
    }

    private var lessons: [Course] { courses.filter { $0.isLesson && $0.source != .deck } }

    /// La leçon ouverte le plus récemment : celle de « Continuer » et du quiz éclair.
    private var resumeCourse: Course? {
        guard let id = snapshot.resumeID else { return nil }
        return courses.first { $0.id == id }
    }

    var body: some View {
        observing
            .task(id: planKey) { refreshPlan() }
            // Le journal des cartes rejoint la série une fois : un ancien compte retrouve la
            // sienne dans l'en-tête dès l'ouverture.
            .task { StudyStreak.adoptReviewHistoryIfNeeded(in: modelContext) }
            .onAppear(perform: appeared)
            .reportsNavigationDepth(for: .today, depth: path.count)
            .returnsHome(path: $path)
    }

    /// Ce que la Home écoute : la série, le retour au premier plan, le retour d'une leçon,
    /// l'onglet Leçons qui demande une nouvelle leçon, la leçon qui arrive, le réseau.
    private var observing: some View {
        presentations
            .onReceive(NotificationCenter.default.publisher(for: .micaboStreakDidChange)) { _ in
                refreshStreak()
                refreshPlan()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                refreshStreak()
                refreshPlan()
            }
            .onChange(of: path.count) { _, depth in
                // De retour d'une leçon : elle a pu avancer.
                if depth == 0 { refreshPlan() }
            }
            .onChange(of: router?.lessonCreationRequests ?? 0, initial: true) { _, requests in
                // « Nouvelle leçon », demandée depuis l'onglet Leçons — même quand c'est elle
                // qui fait apparaître la Home pour la première fois.
                guard requests > handledCreationRequests else { return }
                handledCreationRequests = requests
                openSources()
            }
            .onChange(of: generation.deliveries) { _, _ in openDelivered() }
            .onChange(of: generation.refusals) { _, _ in
                if let trigger = generation.takeRefusal() { paywall = trigger }
            }
            .onChange(of: connectivity.isOnline) { _, online in
                if online { generation.networkReturned() }
            }
    }

    // MARK: La page

    private var page: some View {
        let day = snapshot.day
        return HomeScreen(
            board: HomeBoard.resolve(boardInput),
            exam: HomeExamPill.resolve(snapshot.exam),
            entry: HomeProEntry.resolve(isPro: isPro, offerIsLive: DiscountChip.isLive),
            xp: xp.week,
            league: xp.league.name,
            streak: streak,
            greeted: greeted,
            onGreeted: { greeted = true },
            actions: actions
        )
        .background(V3Color.bg.ignoresSafeArea())
        .tabBarClearance {
            HomeDock(
                composer: composer,
                focused: $focused,
                shortcuts: HomeShortcut.available(
                    isNewcomer: !day.hasCourses,
                    hasLesson: snapshot.resumeID != nil,
                    dueCount: day.dueCount
                ),
                dueCount: day.dueCount,
                isBusy: generation.isBusy || locked != nil,
                actions: actions
            )
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var boardInput: HomeBoardInput {
        HomeBoardInput(
            day: snapshot.day,
            name: snapshot.name,
            greeting: snapshot.greeting,
            phase: generation.phase,
            stage: generation.stage,
            subject: generation.subject,
            hasSupports: generation.hasSupports,
            locked: locked,
            hasLesson: snapshot.resumeID != nil
        )
    }

    private var navigation: some View {
        NavigationStack(path: $path) {
            page
                .navigationDestination(for: Course.self) { course in
                    LessonPathView(course: course)
                }
                .lessonImportPickers(composer, request: $importRequest)
                .fullScreenCover(isPresented: $creating) {
                    LessonCreationFlow(composer: composer) { examDate in
                        // La Home écrit : l'écran des questions se referme sur elle.
                        generate(examDate: examDate)
                        creating = false
                    } onLocked: { lesson in
                        locked = lesson
                        creating = false
                    } onCancel: {
                        creating = false
                    }
                }
                .micaboPaywall($paywall, onSubscribed: subscribed)
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
            .sheet(isPresented: $showsStreak, onDismiss: studyIfAsked) {
                StreakSheet(onStudy: { studiesAfterStreak = true })
            }
            .sheet(isPresented: $showsLeague) {
                LeagueSheet()
            }
            .sheet(item: $editingExam, onDismiss: refreshPlan) { target in
                ExamEditSheet(target: target, lessons: lessons)
            }
    }

    /// Les parcours — réviser ses cartes, le quiz éclair, une séance, l'examen blanc, le
    /// scanner — en plein écran : un glissement ne les referme pas en plein milieu, leur croix
    /// le fait. Chaque outil dit ce qu'il fait la première fois qu'on l'ouvre (`toolIntro`).
    private var presentations: some View {
        sheets
            .fullScreenCover(isPresented: $showsDueReview, onDismiss: refreshPlan) {
                DueCardsReview(courses: DueReview.courses(courses))
                    .toolIntro(.cards)
            }
            .fullScreenCover(item: $quickQuizCourse, onDismiss: refreshPlan) { course in
                QuickQuizSheet(course: course)
                    .toolIntro(.quickQuiz)
            }
            .fullScreenCover(item: $focusPlan, onDismiss: refreshPlan) { plan in
                FocusTimerView(plan: plan)
            }
            .fullScreenCover(item: $mock, onDismiss: refreshPlan) { start in
                MockExamFlow(start: start, lessons: lessons)
                    .toolIntro(.mock)
            }
            .fullScreenCover(isPresented: $showsScanner) {
                ScanExerciseView()
                    .toolIntro(.scan)
            }
            .fullScreenCover(isPresented: $showsWriting) {
                WritingCoachView()
            }
    }

    // MARK: Ce que Home lit

    /// Ce qui fait relire le plan : une séance cochée ou déplacée, un examen ajouté, une tâche
    /// faite, une leçon de plus.
    private var planKey: String {
        let eventStamp = events.map(\.updatedAt).max()?.timeIntervalSince1970 ?? 0
        let examStamp = exams.map(\.updatedAt).max()?.timeIntervalSince1970 ?? 0
        let done = tasks.filter(\.isDone).count
        return "\(courses.count)-\(events.count)-\(eventStamp)-\(exams.count)-\(examStamp)-\(tasks.count)-\(done)"
    }

    /// **La journée, relue** : les cartes dues, la leçon en cours, la séance du calendrier
    /// (`StudyPlan.today`) et le prochain examen (`NextExam.current`) — pour le nouvel élève
    /// aussi, qui a pu donner le sien au parcours d'accueil. Rien n'est écrit quand rien n'a
    /// changé : la Home ne se redessine pas pour rien.
    private func refreshPlan() {
        let now = Date()
        let calendar = Calendar.current
        var day = HomeDay()
        day.hasCourses = !courses.isEmpty
        day.studiedToday = streak.studiedToday
        for course in courses {
            let due = DueReview.dueCount(of: course, now: now)
            day.dueCount += due
            if due > 0 { day.dueLessons += 1 }
        }

        var next = HomeSnapshot()
        if let (course, target) = ResumeTarget.pick(from: courses) {
            next.resumeID = course.id
            if let number = target.circleNumber {
                day.lessonTitle = target.title
                day.lessonStep = number
                day.lessonStepTitle = target.circleTitle
                day.lessonStarted = target.percent > 0
                let finishedToday = course.progress.finishedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
                let openedToday = course.lastOpenedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
                day.lessonAdvancedToday = finishedToday || (openedToday && streak.studiedToday)
            }
        }

        if !courses.isEmpty {
            let agenda = StudyPlan.today(in: modelContext, now: now)
            let examNames = Dictionary(exams.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            day.session = HomeSession.next(in: agenda, now: now, examNames: examNames)
        }

        if let exam = NextExam.current(in: modelContext, now: now) {
            next.exam = HomeExam(name: exam.name, daysLeft: max(0, exam.daysRemaining(from: now)), readiness: nil)
            next.examID = exam.id
            next.examDate = exam.date
        }

        next.day = day
        next.name = HomeGreeting.firstName(OnboardingPreferences.displayName)
        next.greeting = HomeGreeting.moment(hour: calendar.component(.hour, from: now))
        if next != snapshot { snapshot = next }
    }

    private func refreshStreak() {
        let next = StudyStreak.status()
        guard next != streak else { return }
        streak = next
    }

    /// La Home arrive à l'écran : elle relit la journée, écoute le réseau, et lance ce que
    /// l'élève a choisi pendant le parcours d'accueil.
    private func appeared() {
        connectivity.start()
        refreshStreak()
        refreshPlan()
        Haptics.prepare()
        consumeFirstLessonIntent()
    }

    /// **La première leçon choisie pendant le parcours d'accueil** (`FirstLessonIntent`), lue
    /// et effacée : une seule fois. Un sujet part tout de suite à l'écriture — l'élève vient de
    /// répondre à assez de questions, la Home passe à « J'écris ta leçon… » ; « J'ai un cours »
    /// ouvre la feuille des sources.
    private func consumeFirstLessonIntent() {
        guard let intent = FirstLessonIntent.pending else { return }
        FirstLessonIntent.pending = nil
        switch intent {
        case .topic(let topic):
            guard !generation.isBusy else { return }
            composer.draft = topic
            guard composer.canSend else { return }
            if let trigger = LessonAllowance.immediatePaywall(isPro: isPro, source: composer.source, courses: courses) {
                paywall = trigger
                return
            }
            generate(examDate: nil)
        case .importSource:
            openSources()
        }
    }

    // MARK: Les gestes

    private var actions: HomeActions {
        HomeActions(
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
            exam: openExam,
            perform: perform,
            leave: leave,
            shortcut: open,
            sources: openSources,
            scan: { open(.scan) },
            send: send,
            dismissKeyboard: dismissKeyboard
        )
    }

    private func dismissKeyboard() {
        focused = false
    }

    /// **L'**action de la Home. Le nom du geste part dans `home_plan_tapped` : une valeur fixe.
    private func perform(_ action: HomeAction) {
        dismissKeyboard()
        Analytics.track(.homePlanTapped, [
            "step": .text(action.analyticsStep),
            "slot": .text("hero"),
            "exam": .flag(snapshot.exam != nil),
        ])
        switch action.kind {
        case .session:
            if let session = snapshot.day.session { start(session) }
        case .cards:
            showsDueReview = true
        case .lesson, .more:
            if let course = resumeCourse { path.append(course) }
        case .create, .first:
            showsSources = true
        case .unlock:
            paywall = .lessonReady
        case .retry:
            generation.retry()
        }
    }

    /// L'issue discrète sous l'action.
    private func leave(_ exit: HomeExit) {
        switch exit.kind {
        case .cancel:
            generation.cancel()
        case .later:
            // Les supports restent dans la barre : la leçon peut repartir plus tard.
            locked = nil
        }
    }

    /// Une puce d'outil. Le nom de l'outil part dans `home_tool_opened` : une valeur fixe.
    private func open(_ shortcut: HomeShortcut) {
        dismissKeyboard()
        Analytics.track(.homeToolOpened, ["tool": .text(shortcut.analyticsName)])
        switch shortcut {
        case .focus:
            // Une séance de Concentration, à la durée par défaut de l'élève, sans réglage.
            focusPlan = FocusPlan(workMinutes: FocusPlan.defaultMinutes(dailyMinutes: OnboardingPreferences.dailyMinutes))
        case .scan:
            // Le scanner s'ouvre toujours : la lecture de l'énoncé se fait sur l'appareil. La
            // porte de Mika vient à la demande de solution (`SolverSession`).
            showsScanner = true
        case .quiz:
            quickQuizCourse = resumeCourse
        case .cards:
            showsDueReview = true
        case .importSource:
            showsSources = true
        case .writing:
            // Toujours ouvert, comme le scanner : la porte de Mika vient à la demande de
            // relecture (`WritingSession`).
            showsWriting = true
        case .mock:
            mock = MockExamStart(exam: exams.first { $0.id == snapshot.examID })
        case .photo, .pdf, .youtube:
            if let kind = shortcut.source { tapImport(kind) }
        }
    }

    /// La pastille de l'examen : son jour dans le Calendrier, ou l'ajout d'un examen.
    private func openExam() {
        dismissKeyboard()
        if snapshot.exam != nil {
            router?.showCalendar(day: snapshot.examDate)
        } else {
            editingExam = .new
        }
    }

    private func openSources() {
        dismissKeyboard()
        showsSources = true
    }

    /// La séance du plan, lancée comme le calendrier la lance (`FocusPlan.revision`).
    private func start(_ session: HomeSession) {
        let course = courses.first { $0.id == session.courseID }
        focusPlan = .revision(eventID: session.eventID, startMinute: session.startMinute, endMinute: session.endMinute, courseID: course?.id, courseTitle: course?.title)
    }

    /// « Faire une leçon », depuis la feuille de la série, une fois la feuille refermée : la
    /// leçon en cours s'il y en a une, sinon la barre, prête à écrire.
    private func studyIfAsked() {
        guard studiesAfterStreak else { return }
        studiesAfterStreak = false
        if let course = resumeCourse {
            path.append(course)
        } else {
            focused = true
        }
    }

    /// Un import s'ouvre toujours : la lecture se fait sur l'appareil, et c'est l'écriture de la
    /// leçon qui passe par la porte du gratuit (`LessonAllowance.locksImport`, `sendRoute`).
    private func tapImport(_ kind: LessonComposer.Kind) {
        if LessonAllowance.locksImport(kind, isPro: isPro, freeLessonLeft: freeLessonLeft) {
            dismissKeyboard()
            paywall = .generateCourse
            return
        }
        importRequest = kind
    }

    /// La feuille du « + » est refermée : la source choisie s'ouvre maintenant.
    private func openPendingImport() {
        guard let kind = pendingImport else { return }
        pendingImport = nil
        tapImport(kind)
    }

    // MARK: Écrire une leçon

    /// Envoyer ce que la barre a préparé : le paywall d'un sujet seul s'ouvre tout de suite
    /// (`LessonAllowance.immediatePaywall`) ; sinon les deux questions, puis l'écriture.
    private func send() {
        guard composer.canSend, !generation.isBusy else { return }
        dismissKeyboard()
        if let trigger = LessonAllowance.immediatePaywall(isPro: isPro, source: composer.source, courses: courses) {
            paywall = trigger
            return
        }
        locked = nil
        creating = true
    }

    /// La Home écrit la leçon (`LessonGeneration`). Hors ligne, la demande attend le réseau.
    private func generate(examDate: Date?) {
        guard let builder else { return }
        locked = nil
        generation.start(
            composer: composer,
            builder: builder,
            context: modelContext,
            examDate: examDate,
            sendsAsFreeLesson: LessonAllowance.sendsAsFreeLesson(isPro: isPro, source: composer.source, courses: courses),
            online: connectivity.isOnline
        )
    }

    /// La leçon est arrivée : la barre se vide, et la leçon s'ouvre sur son chemin.
    private func openDelivered() {
        guard let course = generation.takeDelivered() else { return }
        composer.reset()
        refreshPlan()
        path.append(course)
    }

    /// Abonné depuis la Home : la leçon qui attendait Pro s'écrit, avec les mêmes supports et
    /// la même date d'examen ; celle que le serveur avait refusée repart.
    private func subscribed() {
        if let lesson = locked {
            generate(examDate: lesson.examDate)
        } else if generation.wasRefused {
            generation.retry()
        }
    }
}
