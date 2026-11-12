import StoreKit
import SwiftData
import SwiftUI

/// **L'écran d'une leçon : tout au même endroit** (lot 10, HOME.md § 2).
///
/// De haut en bas : le retour et le menu « ⋯ » (renommer, recommencer, supprimer) ; la matière,
/// le titre, « 43 % · Étape 4 sur 7 » et la jauge — **où j'en suis** ; **un** bouton plein —
/// **que faire maintenant** : commencer, continuer l'étape en cours, ou, la leçon finie, revoir
/// ses cartes (`LessonNextAction`) ; la grille des huit façons de réviser (`LessonToolGrid`) ;
/// puis le chemin, en zigzag, la signature d'une leçon (`PathMapView`).
///
/// Trois systèmes se superposaient ici — le chemin, une rangée « Réviser autrement », une barre
/// du bas Notes · Quiz · Flashcards, et l'avatar de Mika en haut. Il n'y en a plus qu'un : la
/// barre du bas et l'avatar ont disparu, leurs entrées sont des tuiles de la grille.
///
/// Un parcours (une étape, le quiz, les cartes, à voix haute) s'ouvre en plein écran et se
/// ferme par sa croix, sur la leçon ; une option (lire les notes, Mika, écouter, la carte
/// mentale, la fiche) monte en feuille. Jamais de feuille sur une feuille.
///
/// **Ce qui suit une étape finie s'enchaîne sans minuterie** : l'écran de l'étape se referme,
/// le chemin avance, et ce qui doit venir ensuite (« Leçon terminée », la série) se présente
/// au moment où l'écran précédent a fini de descendre (`onDismiss`), pas « au bout de 1,2 s ».
///
/// Un ancien cours qui s'ouvre ici pour la première fois devient une leçon : on le convertit
/// sur place, Mika au travail.
struct LessonPathView: View {
    let course: Course

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(LessonBuilder.self) private var builder
    @Query(sort: \Exam.date) private var exams: [Exam]

    @State private var session: LessonSession
    @State private var openCircle: PathCircle?
    /// L'étape que l'élève vient de finir : appliquée au chemin une fois son écran refermé.
    @State private var completed: PathCircle?
    @State private var finished = false
    /// Où l'on va en quittant « Leçon terminée », une fois son écran refermé.
    @State private var leaving: LessonFinishedView.Destination?
    @State private var sheet: LessonSheet?
    /// Un parcours ouvert depuis la grille ou le bouton principal : plein écran.
    @State private var run: LessonRun?
    @State private var conversionError: String?
    @State private var scrolledPastHeader = false
    @State private var fullQuizAttempt = 0
    @State private var renaming = false
    @State private var newTitle = ""
    @State private var confirmsDelete = false
    @State private var confirmsReset = false
    /// Un palier franchi : des confettis, une fois.
    @State private var celebration = 0
    /// **La série qui grandit**, une fois par jour, après l'étape (`StreakCelebrationView`).
    @State private var streakCelebration = false
    /// Où l'on allait en quittant « Leçon terminée », quand la série passe entre les deux.
    @State private var afterStreak: LessonFinishedView.Destination?
    /// **« Cette leçon t'a aidé ? »**, posée en bas après la première étape de contenu
    /// terminée, une fois par leçon (`LessonRating`). Elle ne bloque rien.
    @State private var showsRating = false
    /// Un mode de révision ouvert depuis la grille (`LessonTool.revision`).
    @State private var revision: RevisionMode?
    @State private var paywall: PaywallTrigger?
    /// Le mode demandé derrière le paywall : il s'ouvre tout seul une fois l'abonnement pris.
    @State private var pendingRevision: RevisionMode?
    @Environment(ProAccess.self) private var pro: ProAccess?

    init(course: Course) {
        self.course = course
        _session = State(initialValue: LessonSession(course: course))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if course.isLesson {
                path
            } else {
                LessonPreparingView(
                    error: conversionError,
                    onRetry: { Task { await convert() } },
                    onOpenNow: openOffline
                )
            }
        }
        .background(V3Color.bg.ignoresSafeArea())
        .overlay {
            if celebration > 0 {
                ConfettiView(colors: [V3Color.accent, V3Color.green, V3Color.yellow, V3Color.lilac])
                    .id(celebration)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if showsRating {
                LessonRatingCard(course: course, moment: .firstCircle) {
                    withAnimation(LearnMotion.standard) { showsRating = false }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
        .alert(L10n.t("lesson.menu.renameTitle", locale: .resolved()), isPresented: $renaming) {
            TextField(L10n.t("lesson.menu.renamePlaceholder", locale: .resolved()), text: $newTitle)
            Button(L10n.t("lesson.menu.save", locale: .resolved()), action: saveTitle)
            Button(L10n.t("lesson.menu.cancel", locale: .resolved()), role: .cancel) {}
        }
        .confirmationDialog(
            L10n.t("lesson.menu.deleteTitle", locale: .resolved()),
            isPresented: $confirmsDelete,
            titleVisibility: .visible
        ) {
            Button(L10n.t("lesson.menu.delete", locale: .resolved()), role: .destructive, action: deleteLesson)
        } message: {
            Text(L10n.t("ios.home10.lessons.deleteMessage", locale: .resolved()))
        }
        .confirmationDialog(
            L10n.t("lesson.menu.resetTitle", locale: .resolved()),
            isPresented: $confirmsReset,
            titleVisibility: .visible
        ) {
            Button(L10n.t("lesson.menu.reset", locale: .resolved()), role: .destructive, action: resetLesson)
        } message: {
            Text(L10n.t("ios.home10.lesson.resetMessage", locale: .resolved()))
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .enablesSwipeBack()
        .task { await open() }
        .onChange(of: builder.writing) { _, _ in session.reload() }
        // Une conversion finie ailleurs, une synchro qui apporte le chemin ou la progression.
        .onChange(of: course.pathData) { _, _ in session.reload() }
        .onChange(of: course.progressData) { _, _ in session.reload() }
        .fullScreenCover(item: $openCircle, onDismiss: applyCompletion) { circle in
            LessonCircleScreen(session: session, circle: circle) {
                completed = circle
                openCircle = nil
            }
        }
        .fullScreenCover(isPresented: $finished, onDismiss: afterFinished) {
            LessonFinishedView(session: session) { destination in
                if destination == .lessons, !StudyStreak.celebrationIsDue() {
                    // Rien d'autre à montrer : la leçon se replie sous l'écran qui descend.
                    askForReviewAfterFirstLesson()
                    finished = false
                    dismiss()
                    return
                }
                leaving = destination
                finished = false
            }
        }
        .fullScreenCover(isPresented: $streakCelebration, onDismiss: leaveAfterStreak) {
            StreakCelebrationView { streakCelebration = false }
        }
        .sheet(item: revisionSheet) { mode in
            switch mode {
            case .listen:
                ListenView(course: course)
                    .toolIntro(.listen)
                    .presentationDragIndicator(.visible)
            case .voice:
                // Jamais ici : à voix haute s'ouvre en plein écran (`voiceOpen`).
                EmptyView()
            case .mindMap:
                MindMapView(course: course)
                    .toolIntro(.mindMap)
                    .presentationDragIndicator(.visible)
            case .export:
                SheetExportView(digest: LessonDigest(course: course), tone: course.tone)
                    .toolIntro(.sheet)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(isPresented: voiceOpen) {
            VoiceRecallView(session: session) { revision = nil }
        }
        .fullScreenCover(item: $run) { run in
            switch run {
            case .quiz:
                LessonPracticeView(session: session, attempt: fullQuizAttempt)
                    .toolIntro(.quiz)
            case .cards:
                LessonCardsHub(session: session)
                    .toolIntro(.cards)
            }
        }
        .micaboPaywall($paywall, onSubscribed: {
            guard let mode = pendingRevision else { return }
            pendingRevision = nil
            // Le paywall n'a pas de signal de fin de fermeture : le mode attend qu'il soit
            // descendu, deux présentations ne se croisent pas.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { revision = mode }
        })
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .notes:
                LessonNotesReader(session: session)
                    .toolIntro(.notes)
                    .presentationDragIndicator(.visible)
            case .mika:
                LessonMikaView(course: course)
                    .toolIntro(.mika)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: La page

    private var path: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        LessonPathHeader(
                            course: course,
                            session: session,
                            exam: nextExam,
                            next: nextAction,
                            onNext: performNext
                        )
                        .padding(.top, 6)

                        LessonToolGrid(
                            dueCount: session.dueCards().count,
                            isPro: pro?.isPro ?? true,
                            onSelect: openTool
                        )
                        .padding(.horizontal, MicaboSpacing.screen)
                        .padding(.top, 24)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(Text(L10n.t("ios.home10.lesson.modes", locale: .resolved())))

                        Text(L10n.t("ios.home10.lesson.path", locale: .resolved()))
                            .font(V3Font.title)
                            .foregroundStyle(V3Color.ink)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.horizontal, MicaboSpacing.screen)
                            .padding(.top, 28)
                            .padding(.bottom, 4)

                        PathMapView(
                            session: session,
                            tone: course.tone,
                            width: geometry.size.width,
                            onOpen: { openCircle = $0 },
                            onRetry: retry
                        )
                    }
                    .padding(.bottom, 40)
                    .micaboScrollProbes(space: Self.scrollSpace)
                }
                .micaboScrollGeometry(space: Self.scrollSpace) { geometry in
                    // Passé le titre, il monte dans la barre du haut.
                    let past = geometry.offset > 120
                    if past != scrolledPastHeader {
                        withAnimation(LearnMotion.quick) { scrolledPastHeader = past }
                    }
                }
                .scrollIndicators(.hidden)
                // À l'ouverture, on reste en haut : l'en-tête dit où l'on en est et porte le
                // bouton qui y emmène. Le chemin défile seulement quand une étape finie fait
                // avancer l'étape en cours.
                .onChange(of: session.current?.id) { _, id in
                    guard let id else { return }
                    withAnimation(LearnMotion.gentle) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private static let scrollSpace = "lessonPathScroll"

    private var nextExam: Exam? {
        exams
            .filter { $0.courseIDs.contains(course.id) && !$0.isPast() }
            .min { $0.date < $1.date }
    }

    // MARK: La barre du haut

    /// Le retour et le menu « ⋯ ». Le titre de la leçon y monte quand l'en-tête a défilé.
    private var topBar: some View {
        V3TopBar(progress: nil, onBack: { dismiss() }) {
            if course.isLesson {
                Menu {
                    Button {
                        newTitle = course.title
                        renaming = true
                    } label: {
                        Label(L10n.t("lesson.menu.rename", locale: .resolved()), systemImage: "pencil")
                    }
                    Button {
                        confirmsReset = true
                    } label: {
                        Label(L10n.t("lesson.menu.reset", locale: .resolved()), systemImage: "arrow.counterclockwise")
                    }
                    .disabled(session.doneCount == 0)
                    Button(role: .destructive) {
                        confirmsDelete = true
                    } label: {
                        Label(L10n.t("lesson.menu.delete", locale: .resolved()), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(V3Color.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(L10n.t("lesson.menu.more", locale: .resolved())))
            }
        }
        .overlay {
            Text(course.title)
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink)
                .lineLimit(1)
                .padding(.horizontal, 72)
                .opacity(scrolledPastHeader ? 1 : 0)
                .accessibilityHidden(true)
        }
        .background(V3Color.bg)
    }

    // MARK: Agir

    /// Une tuile de la grille. Notes et Mika montent en feuille ; le quiz et les cartes
    /// s'ouvrent en plein écran ; les quatre modes passent par leur porte.
    private func openTool(_ tool: LessonTool) {
        if let mode = tool.revision {
            openRevision(mode)
            return
        }
        switch tool {
        case .notes: sheet = .notes
        case .quiz: startPractice()
        case .cards: run = .cards
        case .mika: sheet = .mika
        case .listen, .voice, .mindMap, .sheet: break
        }
    }

    /// Un mode de révision, par sa porte (`RevisionModeAllowance`) : écouter et la carte
    /// mentale s'ouvrent toujours ; à voix haute après sa séance offerte, et la fiche en PDF,
    /// passent par le paywall sans abonnement.
    private func openRevision(_ mode: RevisionMode) {
        if let trigger = RevisionModeAllowance.gate(mode, isPro: pro?.isPro ?? true) {
            pendingRevision = mode
            paywall = trigger
            return
        }
        pendingRevision = nil
        revision = mode
    }

    /// Les modes qui se consultent montent en feuille.
    private var revisionSheet: Binding<RevisionMode?> {
        Binding(
            get: { revision == .voice ? nil : revision },
            set: { if $0 == nil, revision != .voice { revision = nil } }
        )
    }

    /// À voix haute est un parcours : plein écran, pas une feuille.
    private var voiceOpen: Binding<Bool> {
        Binding(
            get: { revision == .voice },
            set: { if !$0, revision == .voice { revision = nil } }
        )
    }

    /// **La prochaine chose à faire**, celle du bouton plein de l'en-tête.
    private var nextAction: LessonNextAction {
        LessonNextAction.resolve(session: session, dueCount: session.dueCards().count)
    }

    private func performNext() {
        switch nextAction {
        case .start(let circle), .resume(let circle):
            Haptics.medium()
            openCircle = circle
        case .writing:
            Haptics.light()
        case .retry(let circle):
            retry(circle)
        case .review:
            run = .cards
        case .practice:
            startPractice()
        }
    }

    /// Le quiz de la leçon : un nouveau tirage à chaque ouverture.
    private func startPractice() {
        fullQuizAttempt += 1
        run = .quiz
    }

    private func open() async {
        session.markOpened(in: modelContext)
        if course.isLesson {
            builder.resumeIfNeeded(course, in: modelContext)
        } else {
            await convert()
        }
    }

    private func convert() async {
        conversionError = nil
        do {
            try await builder.convert(course, in: modelContext)
            session.reload()
        } catch LessonServiceError.notConfigured {
            // Sans compte ni serveur, rien à attendre : le cours s'ouvre tel qu'il est.
            openOffline()
        } catch let error as LessonServiceError where error == .courseUnknown || error == .accountRequired {
            // La synchro puis un second essai n'ont pas suffi (`LessonBuilder.convert`), ou
            // aucun compte ne peut payer la conversion : l'élève n'est pas bloqué devant son
            // propre cours, il s'ouvre sans le modèle.
            openOffline()
        } catch {
            conversionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func openOffline() {
        builder.convertOffline(course, in: modelContext)
        conversionError = nil
        session.reload()
    }

    private func retry(_ circle: PathCircle) {
        let themes: [Int]
        switch circle.kind {
        case .notes(let theme): themes = [theme]
        case .quiz(_, let covered), .final(let covered): themes = covered
        case .intro: themes = []
        }
        let chapters = themes.compactMap(session.chapter(at:)).filter { $0.status == .failed }
        for chapter in chapters {
            Task { await builder.retry(chapter, in: modelContext) }
        }
        session.reload()
    }

    // MARK: Une étape finie

    /// L'écran de l'étape vient de se refermer. Si elle a été menée au bout, le chemin avance :
    /// le rond se coche, le trait gagne un segment, le suivant devient l'étape en cours. Un
    /// palier lance ses confettis ; la dernière étape ouvre « Leçon terminée » ; sinon la série
    /// se fête si c'est son jour.
    private func applyCompletion() {
        guard let circle = completed else { return }
        completed = nil
        let firstContent = LessonRating.isFirstContentCircle(circle, doneBefore: session.progress.done, circles: session.circles)
        withAnimation(LearnMotion.gentle) {
            session.complete(circle, in: modelContext)
        }
        Haptics.success()
        if circle.isMilestone {
            celebration += 1
            Haptics.burst(count: 3, over: 0.4)
        }
        if case .final = circle.kind {
            finished = true
            return
        }
        offerRatingIfDue(afterFirstContent: firstContent, circle: circle)
        celebrateStreakIfNeeded()
    }

    /// **L'avis sur la leçon, après sa première étape de contenu**, une fois. Pas sur le Quiz
    /// final : « Leçon terminée » pose la question à sa place.
    private func offerRatingIfDue(afterFirstContent: Bool, circle: PathCircle) {
        guard afterFirstContent else { return }
        if case .final = circle.kind { return }
        guard LessonRating.shouldOffer(course.id, at: .firstCircle) else { return }
        LessonRating.markOffered(course.id, at: .firstCircle)
        withAnimation(LearnMotion.gentle) { showsRating = true }
    }

    /// **Fête la série si c'est le premier jour qu'elle peut l'être**, et rend vrai si elle le
    /// fait.
    ///
    /// Le registre ne réserve la fête qu'au moment où l'écran est libre : un cercle rouvert
    /// entre-temps, une feuille ouverte ou « Leçon terminée » à l'écran, et elle attend la
    /// prochaine étape au lieu de se perdre derrière.
    @discardableResult
    private func celebrateStreakIfNeeded() -> Bool {
        guard openCircle == nil, sheet == nil, run == nil, revision == nil, !finished, !streakCelebration else { return false }
        guard StudyStreak.claimCelebration() else { return false }
        streakCelebration = true
        return true
    }

    /// « Leçon terminée » vient de se refermer : la série d'abord si c'est son jour, puis là où
    /// l'élève a choisi d'aller.
    private func afterFinished() {
        guard let destination = leaving else { return }
        leaving = nil
        if StudyStreak.celebrationIsDue() {
            afterStreak = destination
            if celebrateStreakIfNeeded() { return }
            afterStreak = nil
        }
        leave(to: destination)
    }

    /// Reprend le chemin choisi à la sortie de « Leçon terminée », une fois la série saluée.
    private func leaveAfterStreak() {
        guard let destination = afterStreak else { return }
        afterStreak = nil
        leave(to: destination)
    }

    private func leave(to destination: LessonFinishedView.Destination) {
        askForReviewAfterFirstLesson()
        switch destination {
        case .flashcards:
            run = .cards
        case .lessons:
            dismiss()
        }
    }

    /// **La note, une fois, après la première leçon terminée** (`InAppReviewPrompt`) : « Leçon
    /// terminée » et la série ont eu leur moment, l'élève sait maintenant ce qu'il note. Un
    /// instant après la sortie, pour que la fenêtre du système ne se pose pas sur un écran qui
    /// bouge encore.
    private func askForReviewAfterFirstLesson() {
        guard InAppReviewPrompt.claimAfterFirstLesson() else { return }
        let requestReview = requestReview
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            requestReview()
        }
    }

    private func saveTitle() {
        guard let title = newTitle.nilIfBlank else { return }
        course.title = String(title.prefix(120))
        course.updatedAt = Date()
        try? modelContext.save()
    }

    private func resetLesson() {
        withAnimation(LearnMotion.gentle) {
            session.reset(in: modelContext)
        }
        Haptics.medium()
    }

    private func deleteLesson() {
        dismiss()
        // La leçon s'efface une fois son écran replié : un écran encore à l'image lirait un
        // modèle supprimé.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            try? CourseRepository.delete(course, in: modelContext)
            CourseLedger.noteChange()
        }
    }
}

// MARK: - L'en-tête

/// **L'en-tête d'une leçon** : la matière, le titre, « 43 % · Étape 4 sur 7 » et la jauge,
/// l'examen s'il y en a un, et **le** bouton plein de l'écran.
struct LessonPathHeader: View {
    let course: Course
    let session: LessonSession
    let exam: Exam?
    /// Le bouton plein : ce qu'on fait maintenant. Sans lui (un aperçu), pas de bouton.
    var next: LessonNextAction?
    var onNext: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let subject = course.subject?.nilIfBlank {
                HStack(spacing: 6) {
                    MicaboIconView(icon: course.icon, size: 20, tone: course.tone)
                    Text(SubjectDisplay.subject(subject, locale: .resolved()))
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.ink2)
                        .lineLimit(1)
                }
                .padding(.bottom, 8)
            }
            // Trois lignes au plus, puis le titre se resserre : jamais de « … » sur le nom
            // d'une leçon. En très grand texte, il prend la place qu'il lui faut.
            Text(course.title)
                .font(V3Font.h1)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(typeSize.isAccessibilitySize ? 8 : 3)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            progressLine
                .padding(.top, 14)
            if session.plan?.shortened == true {
                Text(L10n.t("ios.home10.lesson.shortened", locale: .resolved()))
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            if let exam {
                examPill(exam)
                    .padding(.top, 14)
            }
            if let next {
                V3Button(next.title, systemImage: next.symbol, isEnabled: next.isEnabled, action: onNext)
                    .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MicaboSpacing.screen)
    }

    /// « 43 % » à gauche, « Étape 4 sur 7 » à droite, et la jauge pleine largeur, qui avance
    /// à chaque étape finie.
    private var progressLine: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.percent(session.percent, locale: .resolved()))
                    .font(V3Font.display(20))
                    .foregroundStyle(V3Color.accent)
                    .contentTransition(.numericText(value: Double(session.percent)))
                Spacer(minLength: 8)
                Text(Self.stepLine(session: session))
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink2)
            }
            .monospacedDigit()
            V3ProgressBar(value: Double(session.percent) / 100)
        }
        .accessibilityElement(children: .combine)
    }

    /// « Étape 4 sur 7 », et « Leçon terminée » quand le chemin est fini.
    @MainActor
    static func stepLine(session: LessonSession, locale: UiLocale = .resolved()) -> String {
        guard let current = session.current else {
            return L10n.t("lesson.lessons.finished", locale: locale)
        }
        return L10n.t("ios.pol.learn.stepOf", locale: locale, vars: [
            "n": String(current.number),
            "total": String(session.totalCount),
        ])
    }

    /// « Histoire · J-12 » : le nom que l'élève a donné à son examen et son compte à rebours,
    /// dans la langue de l'app, sur la pastille jaune de l'examen.
    private func examPill(_ exam: Exam) -> some View {
        ExamPillLabel(text: ExamCountdown.line(name: exam.name, daysLeft: max(0, exam.daysRemaining())))
    }
}

/// Les feuilles qu'une leçon peut ouvrir : ce qu'on consulte, pas un parcours.
enum LessonSheet: String, Identifiable {
    case notes
    case mika

    var id: String { rawValue }
}

/// Les parcours ouverts depuis la grille ou le bouton principal, en plein écran : on les finit
/// ou on les quitte par la croix, et l'on retombe sur la leçon.
enum LessonRun: String, Identifiable {
    case quiz
    case cards

    var id: String { rawValue }
}

/// **Ce que l'élève fait maintenant**, sur le bouton plein de l'en-tête d'une leçon.
///
/// Tant que le chemin n'est pas fini : commencer (rien de fait), continuer l'étape en cours,
/// attendre qu'elle s'écrive ou la relancer si son écriture a échoué. Le chemin fini, la leçon
/// se révise : les cartes dues d'abord, sinon un quiz.
enum LessonNextAction: Equatable {
    case start(PathCircle)
    case resume(PathCircle)
    case writing(PathCircle)
    case retry(PathCircle)
    case review(Int)
    case practice

    @MainActor
    static func resolve(session: LessonSession, dueCount: Int) -> LessonNextAction {
        if let current = session.current {
            switch session.readiness(of: current) {
            case .ready: return session.doneCount == 0 ? .start(current) : .resume(current)
            case .writing: return .writing(current)
            case .failed: return .retry(current)
            }
        }
        return dueCount > 0 ? .review(dueCount) : .practice
    }

    var title: String {
        switch self {
        case .start:
            L10n.t("ios.pol.learn.next.start", locale: .resolved())
        case .resume(let circle):
            L10n.t("ios.pol.learn.next.resume", locale: .resolved(), vars: ["n": String(circle.number)])
        case .writing(let circle):
            L10n.t("ios.pol.learn.next.writing", locale: .resolved(), vars: ["n": String(circle.number)])
        case .retry:
            L10n.t("lesson.path.retry", locale: .resolved())
        case .review(let count):
            L10n.t("ios.pol.learn.next.review", locale: .resolved(), vars: ["count": String(count)])
        case .practice:
            // « Quiz », pas « Entraînement » : un nom par chose (`MicaboName`).
            L10n.t("ios.home10.lesson.next.quiz", locale: .resolved())
        }
    }

    var symbol: String {
        switch self {
        case .start, .resume: "play.fill"
        case .writing: "pencil.line"
        case .retry: "arrow.clockwise"
        case .review: "rectangle.on.rectangle.angled"
        case .practice: "checklist"
        }
    }

    var isEnabled: Bool {
        if case .writing = self { return false }
        return true
    }
}

/// **Un ancien cours qui devient une leçon** : Mika prépare le chemin.
struct LessonPreparingView: View {
    let error: String?
    let onRetry: () -> Void
    let onOpenNow: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            MikaMascot(mood: error == nil ? .write : .sad, size: 170)
            Text(error == nil
                ? L10n.t("lesson.convert.title", locale: .resolved())
                : L10n.t("lesson.convert.failed", locale: .resolved()))
                .font(V3Font.h2)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
            Text(error ?? L10n.t("ios.home10.lesson.converting", locale: .resolved()))
                .font(V3Font.body)
                .foregroundStyle(V3Color.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            if error == nil {
                ProgressView()
                    .tint(V3Color.ink2)
                    .padding(.top, 20)
            }
            Spacer(minLength: 0)
            if error != nil {
                VStack(spacing: 8) {
                    V3Button(L10n.t("lesson.path.retry", locale: .resolved()), action: onRetry)
                    V3Button(L10n.t("lesson.convert.openNow", locale: .resolved()), kind: .ghost, action: onOpenNow)
                }
                .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// **L'ancienne barre du bas d'une leçon** (Notes, Quiz, Cartes). L'écran d'une leçon ne la
/// pose plus : ses trois entrées sont des tuiles de `LessonToolGrid`. Elle ne reste que pour
/// l'aperçu d'une leçon dessiné par le parcours d'accueil.
struct LessonNavbar: View {
    enum Entry: CaseIterable {
        case notes
        case quiz
        case flashcards
    }

    var dueCount: Int = 0
    let onSelect: (Entry) -> Void

    var body: some View {
        HStack(spacing: 0) {
            item(.notes, tool: .notes)
            item(.quiz, tool: .quiz)
            item(.flashcards, tool: .cards)
                .overlay(alignment: .top) {
                    if dueCount > 0 {
                        Text("\(dueCount)")
                            .font(V3Font.caption)
                            .foregroundStyle(V3Color.onAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(V3Color.accent, in: Capsule())
                            .offset(x: 22, y: -2)
                    }
                }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 2)
        .background(V3Color.bg)
    }

    private func item(_ entry: Entry, tool: LessonTool) -> some View {
        Button {
            Haptics.light()
            onSelect(entry)
        } label: {
            VStack(spacing: 6) {
                LessonToolIcon(tool: tool, size: 40)
                Text(tool.name.text())
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
    }
}
