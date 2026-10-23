import SwiftData
import SwiftUI

/// **L'écran d'une leçon : son chemin.** Voir `docs/refonte-parcours.md` § 5.3.
///
/// En haut, le retour, le menu « ⋯ » (renommer, recommencer, supprimer) et Mika. La grande
/// illustration de la leçon, son titre, « 27 % · 3 sur 11 étapes » et la barre qui se remplit.
/// Le chemin, centré sur l'étape en cours à l'ouverture ; « Recommencer la leçon » tout en bas.
/// En bas de l'écran, Notes, Quiz et Flashcards. Un ancien cours qui s'ouvre ici pour la
/// première fois devient une leçon : on le convertit sur place, Mika au travail.
struct LessonPathView: View {
    let course: Course

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LessonBuilder.self) private var builder
    @Query(sort: \Exam.date) private var exams: [Exam]

    @State private var session: LessonSession
    @State private var openCircle: PathCircle?
    @State private var finished = false
    @State private var sheet: LessonSheet?
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if course.isLesson {
                LessonNavbar(dueCount: session.dueCards().count) { entry in
                    switch entry {
                    case .notes: sheet = .notes
                    case .quiz:
                        fullQuizAttempt += 1
                        sheet = .quiz
                    case .flashcards: sheet = .cards
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
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .notes:
                LessonNotesReader(session: session)
            case .quiz:
                LessonPracticeView(session: session, attempt: fullQuizAttempt)
            case .exam:
                LessonQuizView(
                    session: session,
                    questions: session.fullQuiz(attempt: fullQuizAttempt),
                    title: L10n.t("lesson.exam.mockTitle", locale: .resolved()),
                    circleID: nil,
                    onClose: { self.sheet = nil }
                )
            case .cards:
                LessonCardsHub(session: session)
            case .mika:
                LessonMikaView(course: course)
            }
        }
    }

    // MARK: Le chemin

    private var path: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        LessonPathHeader(course: course, session: session, exam: nextExam)
                            .padding(.top, 60)
                            .padding(.bottom, 44)
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
                        withAnimation(.easeOut(duration: 0.2)) { scrolledPastHeader = past }
                    }
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    if let current = session.current {
                        proxy.scrollTo(current.id, anchor: .center)
                    }
                }
                .onChange(of: session.current?.id) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.6)) {
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
            MicaboCircleButton(systemImage: "chevron.left", style: .light, size: 40) {
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
                MicaboIconView(icon: .mika, size: 34)
                    .frame(width: 40, height: 40)
                    .background(MicaboColor.surface, in: Circle())
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
            withAnimation(.spring(duration: 0.6)) {
                session.complete(circle, in: modelContext)
            }
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

    /// **Fête la série si c'est le premier jour qu'elle peut l'être**, et rend vrai si elle le
    /// fait.
    ///
    /// Le registre ne réserve la fête qu'au moment où l'écran est libre : un cercle rouvert
    /// entre-temps, une feuille ouverte ou « Leçon terminée » à l'écran, et elle attend la
    /// prochaine étape au lieu de se perdre derrière.
    @discardableResult
    private func celebrateStreakIfNeeded() -> Bool {
        guard openCircle == nil, sheet == nil, !finished, !streakCelebration else { return false }
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
        switch destination {
        case .flashcards:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { sheet = .cards }
        case .lessons:
            dismiss()
        }
    }

    private func saveTitle() {
        guard let title = newTitle.nilIfBlank else { return }
        course.title = String(title.prefix(120))
        course.updatedAt = Date()
        try? modelContext.save()
    }

    private func resetLesson() {
        withAnimation(.spring(duration: 0.6)) {
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

    private var tone: LessonTone { course.tone }

    var body: some View {
        VStack(spacing: 18) {
            // 88 points : les icônes 3D font 256 pixels, au-delà elles s'étirent et floutent.
            // Le halo de la couleur de la leçon garde au grand en-tête sa présence.
            MicaboIconView(icon: course.icon, size: 88)
                .shadow(color: tone.vivid.opacity(0.25), radius: 24, x: 0, y: 14)
                .background(
                    Circle()
                        .fill(RadialGradient(colors: [tone.vivid.opacity(0.22), tone.vivid.opacity(0)], center: .center, startRadius: 4, endRadius: 90))
                        .frame(width: 180, height: 180)
                )
                .padding(.vertical, 14)
            Text(course.title)
                .font(MicaboFont.display(30))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 28)
            progressLine
                .padding(.horizontal, 28)
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
        }
    }

    /// « 27 % » à gauche, « 3 sur 11 étapes » à droite, et la barre pleine largeur, qui se
    /// remplit en douceur à chaque étape finie.
    private var progressLine: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(session.percent) %")
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
        .animation(.spring(duration: 0.8, bounce: 0.2), value: session.percent)
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

/// Les feuilles qu'une leçon peut ouvrir.
enum LessonSheet: String, Identifiable {
    case notes
    case quiz
    case exam
    case cards
    case mika

    var id: String { rawValue }
}

/// **Un ancien cours qui devient une leçon** : Mika prépare le chemin.
struct LessonPreparingView: View {
    let error: String?
    let onRetry: () -> Void
    let onOpenNow: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            MikaMascot(mood: error == nil ? .think : .sad, size: 180)
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
                        .buttonStyle(LessonPrimaryButtonStyle())
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
                            .foregroundStyle(MicaboColor.onInk)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(MicaboColor.wrong, in: Capsule())
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
        .animation(.spring(duration: 0.4), value: dueCount)
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
