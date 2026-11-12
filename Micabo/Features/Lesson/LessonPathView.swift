import StoreKit
import SwiftData
import SwiftUI

/// **L'écran d'une leçon : son chemin.** Voir `docs/refonte-parcours.md` § 5.3.
///
/// En haut, le retour, le menu « ⋯ » (renommer, recommencer, supprimer) et Mika. Puis ce qui
/// se lit en trois secondes : l'illustration, le titre, « 27 % · 3 sur 11 étapes » et la barre
/// — **où j'en suis** — et un seul bouton plein — **que faire maintenant** : commencer,
/// continuer l'étape en cours, ou, la leçon finie, réviser ses cartes (`LessonNextAction`).
/// Les autres façons de réviser, en tuiles égales, puis le chemin ; « Recommencer la leçon »
/// tout en bas. En bas de l'écran, Notes, Quiz et Flashcards.
///
/// Un parcours (une étape, le quiz, les flashcards, à voix haute) s'ouvre en plein écran et
/// se ferme par sa croix, en haut à gauche, sur la leçon ; une option (lire les notes, Mika,
/// écouter, la carte mentale, la fiche) monte en feuille. Jamais de feuille sur une feuille.
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
    @State private var finished = false
    @State private var sheet: LessonSheet?
    /// Un parcours ouvert depuis la barre du bas ou le bouton principal : plein écran.
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
    /// **« Cette leçon t'a aidé ? »**, posée sous le chemin après la première étape de contenu
    /// terminée, une fois par leçon (`LessonRating`). Elle ne bloque rien.
    @State private var showsRating = false
    /// Un mode de révision ouvert depuis la rangée sous l'en-tête (`RevisionModesRow`).
    @State private var revision: RevisionMode?
    @State private var paywall: PaywallTrigger?
    /// Le mode demandé derrière le paywall : il s'ouvre tout seul une fois l'abonnement pris
    /// (lot 7). Avant, l'élève revenait sur la leçon sans rien d'ouvert et devait retrouver
    /// la tuile.
    @State private var pendingRevision: RevisionMode?
    @Environment(ProAccess.self) private var pro: ProAccess?

    init(course: Course) {
        self.course = course
        _session = State(initialValue: LessonSession(course: course))
    }

    private var tone: LessonTone { course.tone }

    var body: some View {
        ZStack(alignment: .top) {
            MicaboColor.canvas.ignoresSafeArea()
            if course.isLesson {
                path
            } else {
                LessonPreparingView(
                    error: conversionError,
                    onRetry: { Task { await convert() } },
                    onOpenNow: openOffline
                )
            }
            topBar
            if celebration > 0 {
                ConfettiView(colors: [tone.vivid, tone.pale, MicaboColor.accent, LessonTone.yellow.vivid])
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if course.isLesson {
                LessonNavbar(dueCount: session.dueCards().count) { entry in
                    switch entry {
                    case .notes: sheet = .notes
                    case .quiz: startPractice()
                    case .flashcards: run = .cards
                    }
                }
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
            Text(L10n.t("lesson.menu.deleteMessage", locale: .resolved()))
        }
        .confirmationDialog(
            L10n.t("lesson.menu.resetTitle", locale: .resolved()),
            isPresented: $confirmsReset,
            titleVisibility: .visible
        ) {
            Button(L10n.t("lesson.menu.reset", locale: .resolved()), role: .destructive, action: resetLesson)
        } message: {
            Text(L10n.t("lesson.menu.resetMessage", locale: .resolved()))
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .enablesSwipeBack()
        .task { await open() }
        .onChange(of: builder.writing) { _, _ in session.reload() }
        // Une conversion finie ailleurs, une synchro qui apporte le chemin ou la progression.
        .onChange(of: course.pathData) { _, _ in session.reload() }
        .onChange(of: course.progressData) { _, _ in session.reload() }
        .fullScreenCover(item: $openCircle) { circle in
            LessonCircleScreen(session: session, circle: circle) {
                complete(circle)
            }
        }
        .fullScreenCover(isPresented: $finished) {
            LessonFinishedView(session: session) { destination in
                finished = false
                // La série se fête après la leçon : « Leçon terminée » a son moment, la flamme
                // le sien, et l'on va ensuite là où l'on avait choisi d'aller.
                guard StudyStreak.celebrationIsDue() else {
                    leave(to: destination)
                    return
                }
                afterStreak = destination
                // Le temps que « Leçon terminée » finisse de descendre : deux plein-écrans ne
                // se croisent pas.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if !celebrateStreakIfNeeded() { leaveAfterStreak() }
                }
            }
        }
        .fullScreenCover(isPresented: $streakCelebration, onDismiss: leaveAfterStreak) {
            StreakCelebrationView { streakCelebration = false }
        }
        .sheet(item: revisionSheet) { mode in
            switch mode {
            case .listen:
                ListenView(course: course)
                    .presentationDragIndicator(.visible)
            case .voice:
                // Jamais ici : à voix haute s'ouvre en plein écran (`voiceOpen`).
                EmptyView()
            case .mindMap:
                MindMapView(course: course)
                    .presentationDragIndicator(.visible)
            case .export:
                SheetExportView(digest: LessonDigest(course: course), tone: course.tone)
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
            case .cards:
                LessonCardsHub(session: session)
            }
        }
        .micaboPaywall($paywall, onSubscribed: {
            guard let mode = pendingRevision else { return }
            pendingRevision = nil
            // Le temps que le paywall descende : deux présentations ne se croisent pas.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { revision = mode }
        })
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .notes:
                LessonNotesReader(session: session)
                    .presentationDragIndicator(.visible)
            case .mika:
                LessonMikaView(course: course)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: Le chemin

    private var path: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        LessonPathHeader(
                            course: course,
                            session: session,
                            exam: nextExam,
                            next: nextAction,
                            onNext: performNext
                        )
                        .padding(.top, 56)
                        .padding(.bottom, MicaboSpacing.lg)
                        RevisionModesRow(isPro: pro?.isPro ?? true, tone: tone, onSelect: openRevision)
                            .padding(.bottom, MicaboSpacing.xl)
                        PathMapView(
                            session: session,
                            tone: tone,
                            width: geometry.size.width,
                            onOpen: { openCircle = $0 },
                            onRetry: retry
                        )
                        if session.doneCount > 0 {
                            Button(L10n.t("lesson.menu.reset", locale: .resolved())) { confirmsReset = true }
                                .font(MicaboFont.ui(16, weight: .semibold))
                                .foregroundStyle(MicaboColor.inkTertiary)
                                .buttonStyle(MicaboPressableButtonStyle())
                                .padding(.top, 20)
                        }
                    }
                    .padding(.bottom, 40)
                    .micaboScrollProbes(space: Self.scrollSpace)
                }
                .micaboScrollGeometry(space: Self.scrollSpace) { geometry in
                    // Passé l'en-tête, son titre monte dans la barre du haut.
                    let past = geometry.offset > 230
                    if past != scrolledPastHeader {
                        withAnimation(LearnMotion.quick) { scrolledPastHeader = past }
                    }
                }
                .scrollIndicators(.hidden)
                // À l'ouverture, on reste en haut : l'en-tête dit où l'on en est et porte
                // le bouton qui y emmène. Le chemin défile seulement quand une étape finie
                // fait avancer l'étape en cours.
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

    private var topBar: some View {
        HStack(spacing: 12) {
            MicaboCircleButton(systemImage: "chevron.backward", style: .light, size: 40) {
                dismiss()
            }
            Spacer(minLength: 0)
            Text(course.title)
                .font(MicaboFont.ui(17, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(1)
                .opacity(scrolledPastHeader ? 1 : 0)
            Spacer(minLength: 0)
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
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .frame(width: 40, height: 40)
                        .background(MicaboColor.surface, in: Circle())
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                }
                .accessibilityLabel(Text(L10n.t("lesson.menu.more", locale: .resolved())))
            }
            Button {
                sheet = .mika
            } label: {
                // Mika en avatar, comme partout où il fait moins de 40 points.
                MikaAvatar(size: 40)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(Text(L10n.t("lesson.mika.open", locale: .resolved())))
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.vertical, 8)
        .background {
            if scrolledPastHeader {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .top)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(MicaboColor.hairline).frame(height: 0.5)
                    }
                    .transition(.opacity)
            }
        }
    }

    // MARK: Agir

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

    /// L'entraînement de la barre du bas : un nouveau tirage à chaque ouverture.
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

    private func complete(_ circle: PathCircle) {
        openCircle = nil
        // Le chemin s'anime une fois l'écran du cercle refermé : le cercle se remplit, le
        // trait avance, le suivant reçoit « Continuer ».
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let firstContent = LessonRating.isFirstContentCircle(circle, doneBefore: session.progress.done, circles: session.circles)
            withAnimation(LearnMotion.gentle) {
                session.complete(circle, in: modelContext)
            }
            offerRatingIfDue(afterFirstContent: firstContent, circle: circle)
            Haptics.success()
            if circle.isMilestone {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    celebration += 1
                    Haptics.burst(count: 3, over: 0.4)
                }
            }
            if case .final = circle.kind {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { finished = true }
            } else {
                // La série passe après le chemin : le cercle se remplit, le trait avance, les
                // confettis d'un palier tombent, et seulement ensuite la flamme.
                DispatchQueue.main.asyncAfter(deadline: .now() + (circle.isMilestone ? 2.2 : 1.3)) {
                    celebrateStreakIfNeeded()
                }
            }
        }
    }

    /// **L'avis sur la leçon, après sa première étape de contenu**, une fois. Pas sur le Quiz
    /// final : « Leçon terminée » pose la question à sa place.
    private func offerRatingIfDue(afterFirstContent: Bool, circle: PathCircle) {
        guard afterFirstContent else { return }
        if case .final = circle.kind { return }
        guard LessonRating.shouldOffer(course.id, at: .firstCircle) else { return }
        LessonRating.markOffered(course.id, at: .firstCircle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(LearnMotion.gentle) { showsRating = true }
        }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { run = .cards }
        case .lessons:
            dismiss()
        }
    }

    /// **La note, une fois, après la première leçon terminée** (`InAppReviewPrompt`) : « Leçon
    /// terminée » et la série ont eu leur moment, l'élève sait maintenant ce qu'il note. Un
    /// instant après la sortie, pour que la fenêtre du système ne se pose pas sur un écran qui
    /// descend.
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            try? CourseRepository.delete(course, in: modelContext)
            CourseLedger.noteChange()
        }
    }
}

/// **L'en-tête d'une leçon** : la grande illustration, le titre, « 27 % · 3 sur 11 étapes » et
/// la barre qui se remplit, l'examen s'il y en a un.
struct LessonPathHeader: View {
    let course: Course
    let session: LessonSession
    let exam: Exam?
    /// Le bouton plein : ce qu'on fait maintenant. Sans lui (un aperçu), pas de bouton.
    var next: LessonNextAction?
    var onNext: () -> Void = {}

    private var tone: LessonTone { course.tone }

    var body: some View {
        VStack(spacing: MicaboSpacing.md) {
            // 80 points : les icônes 3D font 256 pixels, au-delà elles s'étirent et floutent.
            // Le halo de la couleur de la leçon garde au grand en-tête sa présence.
            MicaboIconView(icon: course.icon, size: 80, tone: course.tone)
                .shadow(color: tone.vivid.opacity(0.25), radius: 24, x: 0, y: 14)
                .background(
                    Circle()
                        .fill(RadialGradient(colors: [tone.vivid.opacity(0.22), tone.vivid.opacity(0)], center: .center, startRadius: 4, endRadius: 84))
                        .frame(width: 168, height: 168)
                )
                .padding(.vertical, 8)
                .accessibilityHidden(true)
            // Un titre long revient à la ligne, jusqu'à quatre lignes en très grand texte, puis
            // se resserre un peu : jamais de « … » sur le nom d'une leçon.
            Text(course.title)
                .font(MicaboFont.display(28))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MicaboSpacing.screen)
                .accessibilityAddTraits(.isHeader)
            progressLine
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 4)
            if session.plan?.shortened == true {
                Label(L10n.t("lesson.path.shortened", locale: .resolved()), systemImage: "scissors")
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(MicaboColor.surfaceMuted, in: Capsule())
            }
            if let exam {
                examPill(exam)
            }
            if let next {
                nextButton(next)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.top, 4)
            }
        }
    }

    /// « 27 % » à gauche, « 3 sur 11 étapes » à droite, et la barre pleine largeur, qui se
    /// remplit en douceur à chaque étape finie.
    private var progressLine: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.percent(session.percent, locale: .resolved()))
                    .font(MicaboFont.number(26))
                    .foregroundStyle(tone.ink)
                    .contentTransition(.numericText(value: Double(session.percent)))
                Spacer(minLength: 8)
                Text(L10n.t("lesson.path.stepsDone", locale: .resolved(), vars: [
                    "done": String(session.doneCount),
                    "total": String(session.totalCount),
                ]))
                .font(MicaboFont.ui(17, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .contentTransition(.numericText(value: Double(session.doneCount)))
            }
            .monospacedDigit()

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MicaboColor.track)
                    Capsule()
                        .fill(LinearGradient(colors: [tone.vivid, tone.vivid.opacity(0.85)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(14, proxy.size.width * CGFloat(session.percent) / 100))
                        .overlay(alignment: .top) {
                            Capsule().fill(.white.opacity(0.28)).frame(height: 3).padding(.horizontal, 6).padding(.top, 3)
                        }
                        .opacity(session.percent == 0 ? 0.35 : 1)
                }
            }
            .frame(height: 14)
        }
        .animation(LearnMotion.gentle, value: session.percent)
    }

    /// **Le seul bouton plein de l'écran.** Il dit l'étape où il emmène ; pendant que Mika
    /// écrit cette étape, il attend, grisé, au lieu de disparaître.
    private func nextButton(_ next: LessonNextAction) -> some View {
        Button(action: onNext) {
            Label {
                Text(next.title)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: next.symbol)
            }
            .padding(.horizontal, 12)
        }
        .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent, enabled: next.isEnabled))
        .disabled(!next.isEnabled)
    }

    private func examPill(_ exam: Exam) -> some View {
        // La date dans la langue de l'app, pas dans celle du téléphone.
        let date = MicaboCalendar.shortDayLabel(exam.date)
        return Label {
            Text(L10n.t("lesson.path.examPill", locale: .resolved(), vars: [
                "date": date,
                "countdown": countdown(exam),
            ]))
        } icon: {
            MicaboIconView(icon: .exam, size: 20)
        }
        .font(MicaboFont.ui(14, weight: .bold))
        .foregroundStyle(tone.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(tone.pale, in: Capsule())
    }

    private func countdown(_ exam: Exam) -> String {
        let days = exam.daysRemaining()
        return days <= 0
            ? L10n.t("app.exams.countdown.today", locale: .resolved())
            : L10n.t("lesson.path.daysLeft", locale: .resolved(), vars: ["days": String(days)])
    }

}

/// Les feuilles qu'une leçon peut ouvrir : ce qu'on consulte, pas un parcours.
enum LessonSheet: String, Identifiable {
    case notes
    case mika

    var id: String { rawValue }
}

/// Les parcours de la barre du bas, en plein écran : on les finit ou on les quitte par la
/// croix, et l'on retombe sur la leçon.
enum LessonRun: String, Identifiable {
    case quiz
    case cards

    var id: String { rawValue }
}

/// **Ce que l'élève fait maintenant**, sur le bouton plein de l'en-tête d'une leçon.
///
/// Tant que le chemin n'est pas fini : commencer (rien de fait), continuer l'étape en cours,
/// attendre qu'elle s'écrive ou la relancer si son écriture a échoué. Le chemin fini, la leçon
/// se révise : les cartes dues d'abord, sinon l'entraînement.
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
            L10n.t("ios.pol.learn.next.practice", locale: .resolved())
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
        VStack(spacing: 20) {
            Spacer()
            MikaMascot(mood: error == nil ? .write : .sad, size: 150)
            Text(error == nil
                ? L10n.t("lesson.convert.title", locale: .resolved())
                : L10n.t("lesson.convert.failed", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            Text(error ?? L10n.t("lesson.convert.subtitle", locale: .resolved()))
                .font(MicaboFont.ui(16, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
            if error != nil {
                VStack(spacing: 12) {
                    Button(L10n.t("lesson.path.retry", locale: .resolved()), action: onRetry)
                        .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
                    Button(L10n.t("lesson.convert.openNow", locale: .resolved()), action: onOpenNow)
                        .buttonStyle(MicaboSecondaryButtonStyle())
                }
                .padding(.horizontal, 24)
            } else {
                ProgressView().tint(MicaboColor.ink)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

/// **La barre du bas d'une leçon** : Notes, Quiz, Flashcards, trois grandes icônes posées sur
/// un fondu, sans cadre. Les cartes à revoir aujourd'hui se comptent sur la pastille.
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
            item(.notes, icon: .notes, title: L10n.t("lesson.nav.notes", locale: .resolved()))
            item(.quiz, icon: .quiz, title: L10n.t("lesson.nav.quiz", locale: .resolved()))
            item(.flashcards, icon: .cards, title: L10n.t("lesson.nav.flashcards", locale: .resolved()))
                .overlay(alignment: .top) {
                    if dueCount > 0 {
                        Text("\(dueCount)")
                            .font(MicaboFont.ui(12, weight: .heavy))
                            .foregroundStyle(MicaboColor.onAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(MicaboColor.accent, in: Capsule())
                            .offset(x: 22, y: -2)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
        }
        .padding(.horizontal, 12)
        .padding(.top, 26)
        .padding(.bottom, 2)
        .background {
            LinearGradient(
                stops: [
                    .init(color: MicaboColor.canvas.opacity(0), location: 0),
                    .init(color: MicaboColor.canvas.opacity(0.92), location: 0.38),
                    .init(color: MicaboColor.canvas, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
        .animation(LearnMotion.standard, value: dueCount)
    }

    private func item(_ entry: Entry, icon: MicaboIcon, title: String) -> some View {
        Button {
            Haptics.light()
            onSelect(entry)
        } label: {
            VStack(spacing: 6) {
                MicaboIconView(icon: icon, size: 50)
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 4)
                Text(title)
                    .font(MicaboFont.ui(16, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
    }
}
