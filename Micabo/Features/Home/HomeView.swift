import SwiftData
import SwiftUI

/// **Home**, calme et dans l'ordre où on la lit (`docs/refonte-knowunity.md`) :
/// 1. la rangée du haut — l'initiale (le Profil), « ✦ Pro », la série et l'XP ;
/// 2. la scène bleue de la marque — Mika en buste qui parle dans sa bulle, et la barre
///    « comme une conversation » avec son « + » pour les supports ;
/// 3. quatre outils ;
/// 4. « Aujourd'hui » — l'objectif du jour et **une seule** prochaine étape.
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
    @FocusState private var focused: Bool

    private var isPro: Bool { pro?.isPro ?? true }

    /// La leçon offerte n'a pas encore servi : un import peut l'écrire (§ 7).
    private var freeLessonLeft: Bool {
        !isPro && !LessonAllowance.hasUsedFreeLesson(courses: courses)
    }

    var body: some View {
        let resume = ResumeTarget.pick(from: courses)
        let day = today(resume: resume)
        let name = HomeGreeting.firstName(OnboardingPreferences.displayName)
        let moment = HomeGreeting.moment(hour: Calendar.current.component(.hour, from: Date()))
        NavigationStack(path: $path) {
            ScrollView {
                HomeScreen(
                    composer: composer,
                    focused: $focused,
                    isPro: isPro,
                    name: name,
                    greeting: HomeGreeting.lines(name: name, moment: moment, dueCount: day.dueCount),
                    day: day,
                    resume: resume,
                    motion: HomeMotion(still: false, reduceMotion: reduceMotion),
                    appeared: appeared,
                    actions: actions(resume: resume?.0)
                )
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .background(HomePalette.canvas.ignoresSafeArea())
            .tabBarClearance()
            .toolbar(.hidden, for: .navigationBar)
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
            .sheet(isPresented: $showsDueReview) {
                DueCardsReview(courses: DueReview.courses(courses))
            }
            .sheet(item: $quickQuizCourse) { course in
                QuickQuizSheet(course: course)
            }
            .fullScreenCover(isPresented: $showsTimer) {
                FocusTimerView()
            }
            .fullScreenCover(isPresented: $showsScanner) {
                ScanExerciseView()
            }
            // Le journal des cartes rejoint la série une fois : un ancien compte retrouve la
            // sienne dans la pastille dès l'ouverture.
            .task { StudyStreak.adoptReviewHistoryIfNeeded(in: modelContext) }
            .onAppear {
                refreshStreak()
                guard !appeared else { return }
                Haptics.prepare()
                DispatchQueue.main.async { appeared = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: .micaboStreakDidChange)) { _ in refreshStreak() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshStreak() }
            }
        }
        .reportsNavigationDepth(for: .today, depth: path.count)
        .returnsHome(path: $path)
    }

    /// Ce que l'app sait de la journée, pour la carte « Aujourd'hui ».
    private func today(resume: (Course, ResumeTarget)?) -> HomeDay {
        let calendar = Calendar.current
        let now = Date()
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
        return day
    }

    private func actions(resume: Course?) -> HomeActions {
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
            step: { step in
                dismissKeyboard()
                switch step {
                case .cards: showsDueReview = true
                case .lesson: if let resume { path.append(resume) } else { focused = true }
                case .create: focused = true
                }
            },
            tool: { tool in open(tool, resume: resume) },
            dismissKeyboard: dismissKeyboard
        )
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

    /// Un outil, depuis sa tuile.
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
            showsTimer = true
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
    var step: (HomeDay.Step) -> Void = { _ in }
    var tool: (HomeTool) -> Void = { _ in }
    var dismissKeyboard: () -> Void = {}
}

/// **Tout Home, de haut en bas**, sans défilement ni navigation : `HomeView` le pose dans son
/// `ScrollView`, les rendus le dessinent tel quel.
struct HomeScreen: View {
    let composer: LessonComposer
    var focused: FocusState<Bool>.Binding
    let isPro: Bool
    let name: String?
    let greeting: [String]
    let day: HomeDay
    let resume: (Course, ResumeTarget)?
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

            HomeToolsRow(onTool: actions.tool)
                .padding(.top, 16)
                .homeEntrance(2, shown: appeared, motion: motion)

            HomeTodayCard(day: day, resume: resume, motion: motion, onStep: actions.step)
                .padding(.top, 16)
                .homeEntrance(3, shown: appeared, motion: motion)
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
                HStack(spacing: 12) {
                    tile(.pdf)
                    tile(.photo)
                }
                HStack(spacing: 12) {
                    tile(.youtube)
                    tile(.audio)
                }
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

/// Une grande tuile de support : un aplat de couleur vive, l'icône 3D dans un rond de verre,
/// le nom et ce qu'on y met.
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
                    .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        icon
                        labels
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
                }
            }
            .padding(14)
            .background {
                ZStack {
                    LinearGradient(colors: Self.colors(kind), startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 120, height: 120)
                        .offset(x: 70, y: -50)
                }
                .clipShape(RoundedRectangle(cornerRadius: MicaboStage.tileRadius, style: .continuous))
            }
            .shadow(color: Self.colors(kind)[1].opacity(0.35), radius: 12, y: 6)
            .overlay(alignment: .topTrailing) {
                if locked {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LessonTone.yellow.ink)
                        .padding(6)
                        .background(Color(hex: 0xFFF1B8), in: Circle())
                        .padding(10)
                        .accessibilityLabel(Text("Pro"))
                }
            }
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(HomePressStyle(scale: 0.95, feedback: .soft))
        .disabled(!enabled)
    }

    private var icon: some View {
        MicaboIconView(icon: kind.icon, size: 34)
            .frame(width: 52, height: 52)
            .background(Color.white.opacity(0.24), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.t(kind.titleKey, locale: .resolved()))
                .font(MicaboFont.ui(18, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(L10n.t(kind.titleKey + "Sub", locale: .resolved()))
                .font(MicaboFont.ui(13, weight: .bold))
                .opacity(0.92)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.white)
    }

    /// Des aplats assez sombres pour porter du blanc, dans les deux apparences.
    static func colors(_ kind: LessonComposer.Kind) -> [Color] {
        switch kind {
        case .pdf: [Color(hex: 0x4F7DF5), Color(hex: 0x1D4ED8)]
        case .photo: [Color(hex: 0xEC4F96), Color(hex: 0xBE185D)]
        case .youtube: [Color(hex: 0xF0524F), Color(hex: 0xC81E1E)]
        case .audio: [Color(hex: 0x17A774), Color(hex: 0x047857)]
        case .text: [Color(hex: 0x1FA6B8), Color(hex: 0x0E7490)]
        }
    }
}
