import SwiftData
import SwiftUI

/// **Home** : une scène de nuit en haut — l'initiale de l'élève, « ✦ Pro », l'XP et la série ;
/// Mika en grand qui parle dans sa bulle ; la barre « comme une conversation » avec son « + »
/// pour les supports ; les outils en pastilles —, puis sur la page, les missions du jour,
/// la leçon en cours et les trois chiffres (`docs/refonte-knowunity.md`).
///
/// **Un appui à côté du champ range le clavier.** La rangée du haut, Mika, les chiffres et
/// tout le vide entre les blocs le rendent ; les boutons gardent leur appui, parce qu'un geste
/// posé sur un parent passe après ceux de ses enfants. Le geste n'est jamais posé sur la barre
/// elle-même : un appui dans le champ doit l'ouvrir, pas le refermer aussitôt.
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
    /// La ligue de la semaine (`docs/refonte-knowunity.md` § 3) : la pastille XP et la pastille.
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
                    freeLessonLeft: freeLessonLeft,
                    name: name,
                    greeting: HomeGreeting.lines(name: name, moment: moment, dueCount: day.dueCount),
                    day: day,
                    resume: resume,
                    stats: HomeStats(courses: courses, extraSeconds: FocusLog.totalSeconds),
                    motion: HomeMotion(still: false, reduceMotion: reduceMotion),
                    appeared: appeared,
                    actions: actions(resume: resume?.0)
                )
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .background(HomeScreen.pageBackground.ignoresSafeArea())
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

    /// Ce que l'app sait de la journée, pour les missions.
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
            importKind: tapImport,
            send: send,
            mission: { kind in
                dismissKeyboard()
                switch kind {
                case .cards: showsDueReview = true
                case .lesson: if let resume { path.append(resume) }
                case .create: focused = true
                case .streak: break
                }
            },
            review: {
                dismissKeyboard()
                showsDueReview = true
            },
            continueLesson: {
                if let resume { path.append(resume) }
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

    /// PDF, Photo, Audio et YouTube sont Pro ; la leçon offerte, elle, peut venir de n'importe
    /// quel support (`docs/refonte-knowunity.md` § 7). Une fois servie, les imports ouvrent le
    /// paywall comme avant.
    private func tapImport(_ kind: LessonComposer.Kind) {
        if kind != .text && !isPro && !freeLessonLeft {
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

    /// Un outil, depuis sa pastille.
    private func open(_ tool: HomeToolsGrid.Tool, resume: Course?) {
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
        if let trigger = LessonAllowance.gate(isPro: isPro, source: composer.source, courses: courses) {
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
    var importKind: (LessonComposer.Kind) -> Void = { _ in }
    var send: () -> Void = {}
    var mission: (HomeMission.Kind) -> Void = { _ in }
    var review: () -> Void = {}
    var continueLesson: () -> Void = {}
    var tool: (HomeToolsGrid.Tool) -> Void = { _ in }
    var dismissKeyboard: () -> Void = {}
}

/// **Tout Home, de haut en bas**, sans défilement ni navigation : `HomeView` le pose dans son
/// `ScrollView`, les rendus le dessinent tel quel.
struct HomeScreen: View {
    let composer: LessonComposer
    var focused: FocusState<Bool>.Binding
    let isPro: Bool
    let freeLessonLeft: Bool
    let name: String?
    let greeting: [String]
    let day: HomeDay
    let resume: (Course, ResumeTarget)?
    let stats: HomeStats
    let motion: HomeMotion
    let appeared: Bool
    var streakPreview: StudyStreak.Status?
    let actions: HomeActions

    /// Le fond de la page, derrière le défilement : le haut du ciel sous l'heure et la batterie,
    /// la page dessous — c'est elle qu'on voit quand on tire la liste vers le haut.
    static var pageBackground: some View {
        VStack(spacing: 0) {
            HomePalette.heroTop.frame(height: 160)
            HomePalette.canvas
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            hero
            page
        }
        .frame(maxWidth: .infinity)
        .background(HomePalette.canvas)
    }

    // MARK: La scène

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeTopBar(
                name: name,
                isPro: isPro,
                onProfile: actions.profile,
                onPro: actions.pro,
                onLeague: actions.league,
                onStreak: actions.streak,
                streakPreview: streakPreview
            )
            .padding(.horizontal, MicaboSpacing.screen)
            .homeEntrance(0, shown: appeared, motion: motion)
            .background(dismissArea)

            HomeMikaStage(lines: greeting, isThinking: composer.isReading, motion: motion)
                .padding(.horizontal, MicaboSpacing.screen - 6)
                .homeEntrance(1, shown: appeared, motion: motion)
                // Le toucher fait aussi ranger le clavier : Mika est au-dessus de la barre,
                // là où l'on appuie pour sortir du champ.
                .simultaneousGesture(TapGesture().onEnded { actions.dismissKeyboard() })

            HomeComposerBar(
                composer: composer,
                focused: focused,
                isPro: isPro,
                freeLessonLeft: freeLessonLeft,
                isThinking: composer.isReading,
                onImport: actions.importKind,
                onSend: actions.send,
                onSources: actions.sources
            )
            .padding(.horizontal, MicaboSpacing.screen)
            .homeEntrance(2, shown: appeared, motion: motion)

            HomeToolChips(dueCount: day.dueCount, motion: motion, onReview: actions.review, onTool: actions.tool)
                .padding(.top, 4)
                .homeEntrance(3, shown: appeared, motion: motion)
        }
        .padding(.top, 8)
        .padding(.bottom, 28)
        .background {
            // Le ciel monte sous l'heure et la batterie, et au-delà quand on tire la page.
            VStack(spacing: 0) {
                HomePalette.heroTop.frame(height: 600)
                HomeSky(motion: motion)
            }
            .padding(.top, -600)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 36, bottomTrailingRadius: 36, style: .continuous))
            .onTapGesture(perform: actions.dismissKeyboard)
        }
    }

    // MARK: La page

    private var page: some View {
        VStack(alignment: .leading, spacing: 22) {
            HomeTodayCard(day: day, motion: motion, onMission: actions.mission)
                .homeEntrance(4, shown: appeared, motion: motion)
            if let resume {
                ResumeCard(course: resume.0, target: resume.1, action: actions.continueLesson)
                    .homeEntrance(5, shown: appeared, motion: motion)
            }
            HomeStatsRow(stats: stats)
                .homeEntrance(6, shown: appeared, motion: motion)
                .contentShape(Rectangle())
                .onTapGesture(perform: actions.dismissKeyboard)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Le vide entre les blocs : rien n'y est touchable, l'appui tombe sur ce fond.
        .background(dismissArea)
    }

    private var dismissArea: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(perform: actions.dismissKeyboard)
    }
}

// MARK: - La question

/// **« Qu'est-ce que tu veux apprendre aujourd'hui ? »**, en grand, le mot « apprendre » dans
/// une couleur qui ressort. Le mot est marqué `**…**` dans le catalogue, dans chaque langue.
///
/// **Centrée, sur toute la largeur de la barre.** Calée à gauche, avec Mika perché à droite
/// en dessous, la question avait l'air poussée de côté : deux lignes de longueurs inégales
/// contre un bord, un personnage contre l'autre, et un grand vide entre les deux. Centrée,
/// elle tombe dans l'axe de Mika et de la barre, et l'écran se lit de haut en bas sur une
/// seule ligne.
struct HomeTitle: View {
    var body: some View {
        Self.text(L10n.t("lesson.home.title", locale: .resolved()))
            .font(MicaboFont.display(34))
            .tracking(MicaboTracking.tight)
            .foregroundStyle(MicaboColor.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    /// Le texte, le mot marqué en dégradé bleu-violet.
    static func text(_ source: String) -> Text {
        let parts = source.components(separatedBy: "**")
        var out = Text("")
        for (index, part) in parts.enumerated() where !part.isEmpty {
            if index % 2 == 1 {
                out = out + Text(part).foregroundStyle(
                    LinearGradient(colors: [MicaboColor.accent, MicaboColor.keyword], startPoint: .leading, endPoint: .trailing)
                )
            } else {
                out = out + Text(part)
            }
        }
        return out
    }
}

/// **Mika, perché sur la barre** : ses pattes et son ombre posées sur le bord haut, au milieu,
/// sous la question. Il fait coucou, puis attend ; il réfléchit pendant qu'un support se lit.
struct HomePerch: View {
    var isThinking = false

    static let size: CGFloat = 96
    /// La place qu'il prend au-dessus de la barre : sa taille, moins ce qui se pose dessus.
    static let height: CGFloat = size - sink
    /// Ce qui descend sous le bord : les pattes et l'ombre, pour qu'il soit assis, pas posé à
    /// côté.
    static let sink: CGFloat = 10

    @State private var mood: MikaMood = .wave

    var body: some View {
        MikaMascot(mood: isThinking ? .think : mood, size: Self.size, reactsToTap: true)
            .frame(width: Self.size, height: Self.size)
            .task {
                try? await Task.sleep(for: .seconds(2.4))
                mood = .idle
            }
    }
}

// MARK: - La barre

/// **La barre, comme une conversation** : les supports déposés en pastilles au-dessus, le
/// champ, puis une rangée — le « + » qui ouvre tous les supports en grandes tuiles, quatre
/// raccourcis (PDF, photo, YouTube, audio) et la flèche d'envoi dans le dégradé de Micabo.
///
/// Posée en verre sur le ciel de Home. Ce qui compte n'a pas bougé : les pastilles, le texte
/// d'échec, le plafond de supports, `canSend`, le focus ; la porte du gratuit reste dans
/// `HomeView.send()` et `tapImport`.
struct HomeComposerBar: View {
    let composer: LessonComposer
    var focused: FocusState<Bool>.Binding
    let isPro: Bool
    /// La leçon offerte reste : les imports n'ont pas de couronne (§ 7).
    var freeLessonLeft = false
    var isThinking = false
    let onImport: (LessonComposer.Kind) -> Void
    let onSend: () -> Void
    /// Le « + » : la feuille des supports. Sans elle, il ouvre le texte collé.
    var onSources: (() -> Void)?

    @Environment(\.homeStill) private var still

    /// Les raccourcis de la rangée ; le texte collé est dans la feuille du « + ».
    static let shortcuts: [LessonComposer.Kind] = [.pdf, .photo, .youtube, .audio]

    var body: some View {
        @Bindable var composer = composer
        let isFocused = focused.wrappedValue
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                if !composer.supports.isEmpty {
                    supportsRow
                    if let failure = composer.supports.compactMap(\.failure).last {
                        Text(failure)
                            .font(MicaboFont.ui(13, weight: .bold))
                            .foregroundStyle(HomePalette.heroError)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                field(draft: $composer.draft)

                HStack(spacing: 6) {
                    plusButton
                    ForEach(Self.shortcuts, id: \.self) { kind in
                        shortcut(kind)
                    }
                    Spacer(minLength: 4)
                    sendButton
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(Color.white.opacity(isFocused ? 0.13 : 0.09), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(hex: 0x7AA2FF).opacity(isFocused ? 1 : 0.75), Color(hex: 0xB78CFF).opacity(isFocused ? 1 : 0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isFocused ? 2 : 1.2
                    )
            )
            .shadow(color: HomePalette.glowBlue.opacity(isFocused ? 0.5 : 0.28), radius: isFocused ? 24 : 18, y: 8)
            .animation(.easeOut(duration: 0.25), value: isFocused)
            .animation(.spring(duration: 0.3), value: composer.supports.count)

            if !composer.hasRoom {
                Text(L10n.t("lesson.home.supportsFull", locale: .resolved(), vars: ["n": String(LessonComposer.maximumSupports)]))
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(HomePalette.heroInkSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var placeholder: String {
        composer.supports.isEmpty
            ? L10n.t("lesson.home.placeholder", locale: .resolved())
            : L10n.t("lesson.home.placeholderWithSupports", locale: .resolved())
    }

    @ViewBuilder
    private var supportsRow: some View {
        let chips = HStack(spacing: 8) {
            ForEach(composer.supports) { support in
                SupportChip(support: support) {
                    withAnimation(.spring(duration: 0.3)) { composer.remove(support.id) }
                }
            }
        }
        if still {
            // Les rendus ne dessinent pas ce qui défile : la même rangée, coupée au bord.
            Color.clear
                .frame(height: 38)
                .overlay(alignment: .leading) { chips.fixedSize() }
                .clipped()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                chips.padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    @ViewBuilder
    private func field(draft: Binding<String>) -> some View {
        Group {
            if still {
                Text(draft.wrappedValue.isEmpty ? placeholder : draft.wrappedValue)
                    .foregroundStyle(draft.wrappedValue.isEmpty ? HomePalette.heroInkTertiary : HomePalette.heroInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(
                    text: draft,
                    prompt: Text(placeholder).foregroundStyle(HomePalette.heroInkTertiary),
                    axis: .vertical
                ) {
                    Text(placeholder)
                }
                .foregroundStyle(HomePalette.heroInk)
                .tint(Color.white)
                .lineLimit(1...5)
                .focused(focused)
                .submitLabel(.send)
                .onSubmit(onSend)
            }
        }
        .font(MicaboFont.ui(18, weight: .semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .frame(minHeight: 46, alignment: .topLeading)
    }

    private var plusButton: some View {
        Button {
            if let onSources {
                onSources()
            } else {
                onImport(.text)
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(HomePalette.brand)
                .frame(width: 40, height: 40)
                .background(Color.white, in: Circle())
                .shadow(color: Color.black.opacity(0.2), radius: 6, y: 3)
        }
        .buttonStyle(HomePressStyle(scale: 0.88, feedback: .soft))
        .disabled(!composer.hasRoom)
        .opacity(composer.hasRoom ? 1 : 0.45)
        .accessibilityLabel(Text(L10n.t("ios.home2.addSource", locale: .resolved())))
    }

    private func shortcut(_ kind: LessonComposer.Kind) -> some View {
        let locked = kind != .text && !isPro && !freeLessonLeft
        return Button { onImport(kind) } label: {
            MicaboIconView(icon: kind.icon, size: 24, dimmed: !composer.hasRoom)
                .frame(width: 38, height: 38)
                .homeGlass(Circle())
                .overlay(alignment: .topTrailing) {
                    if locked {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(LessonTone.yellow.ink)
                            .padding(3)
                            .background(Color(hex: 0xFFF1B8), in: Circle())
                            .offset(x: 3, y: -2)
                    }
                }
        }
        .buttonStyle(HomePressStyle(scale: 0.86))
        .disabled(!composer.hasRoom)
        .accessibilityLabel(Text(L10n.t(kind.titleKey, locale: .resolved())))
        .accessibilityValue(locked ? Text("Pro") : Text(""))
    }

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(Color.white.opacity(composer.canSend ? 1 : 0.5))
                .frame(width: 46, height: 46)
                .background {
                    if composer.canSend {
                        Circle().fill(HomePalette.brand)
                    } else {
                        Circle().fill(Color.white.opacity(0.14))
                    }
                }
                .overlay(Circle().strokeBorder(Color.white.opacity(composer.canSend ? 0.3 : 0.12), lineWidth: 1))
                .shadow(color: HomePalette.glowViolet.opacity(composer.canSend ? 0.6 : 0), radius: 12, y: 4)
                .scaleEffect(composer.canSend ? 1 : 0.94)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: composer.canSend)
        }
        .buttonStyle(HomePressStyle(scale: 0.88, feedback: .medium))
        .disabled(!composer.canSend)
        .accessibilityLabel(Text(L10n.t("lesson.home.send", locale: .resolved())))
    }
}

private extension LessonComposer.Support {
    var failure: String? {
        if case .failed(let message) = state { return message }
        return nil
    }
}

/// **Les cinq supports, en petit, sous la barre** : une ligne de pastilles, l'icône 3D et
/// son nom. La barre reste ce qu'on voit d'abord ; un support Pro porte sa petite couronne
/// pour qui n'est pas abonné, une fois la leçon offerte servie (`docs/refonte-knowunity.md`
/// § 7 : tant qu'elle reste, elle peut venir d'un import).
struct ImportGrid: View {
    let isPro: Bool
    var freeLessonLeft = false
    var enabled = true
    let onImport: (LessonComposer.Kind) -> Void

    private static let kinds: [LessonComposer.Kind] = [.pdf, .photo, .audio, .youtube, .text]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Self.kinds, id: \.self) { kind in
                ImportChip(kind: kind, locked: kind != .text && !isPro && !freeLessonLeft, enabled: enabled) { onImport(kind) }
            }
        }
    }
}

/// Une pastille d'import : l'icône 3D, le nom dessous, en petit.
struct ImportChip: View {
    let kind: LessonComposer.Kind
    var locked = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                MicaboIconView(icon: kind.icon, size: 30, dimmed: !enabled)
                Text(L10n.t(kind.titleKey, locale: .resolved()))
                    .font(MicaboFont.ui(12, weight: .heavy))
                    .foregroundStyle(enabled ? MicaboColor.inkSecondary : MicaboColor.inkTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(MicaboColor.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if locked {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(LessonTone.yellow.ink)
                        .padding(4)
                        .background(LessonTone.yellow.pale, in: Circle())
                        .offset(x: 3, y: -3)
                        .accessibilityLabel(Text("Pro"))
                }
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .disabled(!enabled)
    }
}

/// Une tuile d'import : son icône 3D, son nom, et pour les grandes, ce qu'on y met.
struct ImportButton: View {
    enum Size {
        case large
        case medium
    }

    let kind: LessonComposer.Kind
    var size: Size = .medium
    var locked = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: size == .large ? .leading : .center, spacing: size == .large ? 10 : 8) {
                MicaboIconView(icon: kind.icon, size: size == .large ? 58 : 46, dimmed: !enabled)
                VStack(alignment: size == .large ? .leading : .center, spacing: 2) {
                    Text(L10n.t(kind.titleKey, locale: .resolved()))
                        .font(MicaboFont.ui(size == .large ? 19 : 16, weight: .heavy))
                        .foregroundStyle(enabled ? MicaboColor.ink : MicaboColor.inkTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if size == .large {
                        Text(L10n.t(kind.titleKey + "Sub", locale: .resolved()))
                            .font(MicaboFont.ui(13, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(size == .large ? 16 : 12)
            .frame(maxWidth: .infinity, minHeight: size == .large ? 150 : 112, alignment: size == .large ? .topLeading : .center)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(MicaboColor.stroke)
                    .offset(y: 4)
            )
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
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .disabled(!enabled)
    }
}

/// Un support déposé : son icône, son nom, et où en est sa lecture.
struct SupportChip: View {
    let support: LessonComposer.Support
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if support.state == .reading {
                    ProgressView().controlSize(.small)
                } else {
                    MicaboIconView(icon: support.kind.icon, size: 22)
                }
            }
            .frame(width: 24, height: 24)
            Text(support.title)
                .font(MicaboFont.ui(14, weight: .bold))
                .foregroundStyle(isFailed ? MicaboColor.wrongInk : MicaboColor.ink)
                .lineLimit(1)
                .frame(maxWidth: 150, alignment: .leading)
            Button(action: onRemove) {
                Image(systemName: isFailed ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isFailed ? MicaboColor.wrong : MicaboColor.inkTertiary)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(Text(L10n.t("lesson.home.removeSupport", locale: .resolved())))
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .background(isFailed ? MicaboColor.wrongSoft : MicaboColor.canvas, in: Capsule())
        .overlay(Capsule().strokeBorder(isFailed ? MicaboColor.wrong.opacity(0.4) : MicaboColor.stroke, lineWidth: 1))
        .transition(.scale.combined(with: .opacity))
    }

    private var isFailed: Bool {
        if case .failed = support.state { return true }
        return false
    }
}

// MARK: - Les chiffres

/// X h de révision · X leçons apprises · X flashcards apprises : trois pastilles colorées de
/// la même taille, au bas de Home. Elles disent où on en est sans prendre la place.
struct HomeStatsRow: View {
    let stats: HomeStats

    var body: some View {
        HStack(spacing: 8) {
            pill(stats.formattedTime(), L10n.t("lesson.home.statTime", locale: .resolved()), icon: .hourglass, tone: .blue)
            pill(String(stats.learnedLessons), L10n.t("lesson.home.statLessons", locale: .resolved()), icon: .diploma, tone: .mint)
            pill(String(stats.learnedCards), L10n.t("lesson.home.statCards", locale: .resolved()), icon: .cards, tone: .pink)
        }
    }

    private func pill(_ value: String, _ label: String, icon: MicaboIcon, tone: LessonTone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                MicaboIconView(icon: icon, size: 24)
                Text(value)
                    .font(MicaboFont.number(19, weight: .black))
                    .foregroundStyle(tone.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(label)
                .font(MicaboFont.ui(12, weight: .bold))
                .foregroundStyle(HomePalette.inkSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 78, maxHeight: 78, alignment: .topLeading)
        .background(tone.pale, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tone.vivid.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Reprendre

/// **La leçon en cours** : son icône sur une tuile de sa couleur, son titre, le cercle où elle
/// attend, une barre qui dit où on en est, et la lecture dans le dégradé de Micabo.
struct ResumeCard: View {
    let course: Course
    let target: ResumeTarget
    let action: () -> Void

    var body: some View {
        let tone = course.tone
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [tone.vivid.opacity(0.95), tone.vivid.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    MicaboIconView(icon: course.icon, size: 42)
                }
                .frame(width: 66, height: 66)
                .shadow(color: tone.vivid.opacity(0.35), radius: 10, y: 5)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("lesson.home.resume", locale: .resolved()))
                        .font(MicaboFont.ui(12, weight: .black))
                        .tracking(MicaboTracking.caps)
                        .textCase(.uppercase)
                        .foregroundStyle(tone.ink)
                    Text(target.title)
                        .font(MicaboFont.ui(17, weight: .black))
                        .foregroundStyle(HomePalette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(HomePalette.inkSecondary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(HomePalette.track)
                                Capsule()
                                    .fill(LinearGradient(colors: [tone.vivid, tone.vivid.opacity(0.75)], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(8, proxy.size.width * CGFloat(target.percent) / 100))
                            }
                        }
                        .frame(height: 7)
                        Text(percent)
                            .font(MicaboFont.ui(12, weight: .black))
                            .foregroundStyle(tone.ink)
                            .monospacedDigit()
                            .fixedSize()
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.white)
                    .offset(x: 1)
                    .frame(width: 46, height: 46)
                    .background(HomePalette.brand, in: Circle())
                    .shadow(color: HomePalette.glowViolet.opacity(0.4), radius: 10, y: 4)
            }
            .padding(14)
            .homeCard(radius: 26)
        }
        .buttonStyle(HomePressStyle(scale: 0.97, feedback: .soft))
    }

    private var subtitle: String {
        guard let number = target.circleNumber, let title = target.circleTitle else {
            return L10n.t("lesson.home.resumeDone", locale: .resolved())
        }
        return L10n.t("lesson.home.resumeCircle", locale: .resolved(), vars: ["n": String(number), "title": title])
    }

    private var percent: String {
        (Double(target.percent) / 100).formatted(.percent.precision(.fractionLength(0)).locale(Locale(identifier: UiLocale.resolved().rawValue)))
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
        .presentationCornerRadius(32)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                MikaMascot(mood: .happy, size: 64)
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
        kind != .text && !isPro && !freeLessonLeft
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
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        case .text: [Color(hex: 0x9061F9), Color(hex: 0x6D28D9)]
        }
    }
}
