import SwiftData
import SwiftUI

/// **L'écran d'une leçon : son chemin.** Voir `docs/refonte-parcours.md` § 5.3.
///
/// En haut, le retour et Mika ; l'icône de la leçon, son titre, sa progression, son examen. Le
/// chemin, centré sur le cercle en cours à l'ouverture. En bas, la navbar interne : Notes, Quiz,
/// Flashcards. Un ancien cours qui s'ouvre ici pour la première fois devient une leçon : on le
/// convertit sur place, Mika au travail.
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
                .padding(.bottom, 4)
            }
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
                switch destination {
                case .flashcards:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { sheet = .cards }
                case .lessons:
                    dismiss()
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .notes:
                LessonNotesReader(session: session)
            case .quiz:
                LessonQuizView(
                    session: session,
                    questions: session.fullQuiz(attempt: fullQuizAttempt),
                    title: L10n.t("lesson.quiz.fullTitle", locale: .resolved()),
                    circleID: nil,
                    onClose: { self.sheet = nil }
                )
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
                        header
                            .padding(.top, 64)
                            .padding(.bottom, 28)
                        PathMapView(
                            session: session,
                            tone: tone,
                            width: geometry.size.width,
                            onOpen: { openCircle = $0 },
                            onRetry: retry
                        )
                    }
                    .padding(.bottom, 24)
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

    private var header: some View {
        VStack(spacing: 14) {
            MicaboIconView(icon: course.icon, size: 96)
            Text(course.title)
                .font(MicaboFont.title)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)
            progressLine
            if let exam = nextExam {
                examPill(exam)
                if (1...7).contains(exam.daysRemaining()) {
                    mockExamBanner(exam)
                }
            }
        }
    }

    private var progressLine: some View {
        VStack(spacing: 8) {
            Text(L10n.t("lesson.path.progress", locale: .resolved(), vars: [
                "done": String(session.doneCount),
                "total": String(session.totalCount),
                "percent": String(session.percent),
            ]))
            .font(MicaboFont.ui(15, weight: .bold))
            .foregroundStyle(MicaboColor.inkSecondary)
            .monospacedDigit()

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MicaboColor.track)
                    Capsule()
                        .fill(tone.vivid)
                        .frame(width: proxy.size.width * CGFloat(session.percent) / 100)
                }
            }
            .frame(width: 180, height: 6)
            .animation(.easeInOut(duration: 0.6), value: session.percent)
        }
    }

    private func examPill(_ exam: Exam) -> some View {
        let date = exam.date.formatted(.dateTime.day().month(.abbreviated))
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

    /// À l'approche de l'examen, l'examen blanc : le quiz complet de la leçon.
    private func mockExamBanner(_ exam: Exam) -> some View {
        Button {
            fullQuizAttempt += 1
            sheet = .exam
        } label: {
            HStack(spacing: 12) {
                MicaboIconView(icon: .quiz, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("lesson.exam.mockTitle", locale: .resolved()))
                        .font(MicaboFont.label)
                        .foregroundStyle(MicaboColor.ink)
                    Text(L10n.t("lesson.exam.mockSubtitle", locale: .resolved(), vars: ["countdown": countdown(exam)]))
                        .font(MicaboFont.ui(14, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(14)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .micaboElevation(.row)
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .padding(.horizontal, MicaboSpacing.screen)
    }

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
        case .quiz(_, let covered): themes = covered
        default: themes = []
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
            if case .conclusion = circle.kind {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { finished = true }
            }
        }
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

/// **La navbar interne** : une pilule de verre, trois entrées.
struct LessonNavbar: View {
    enum Entry: CaseIterable {
        case notes
        case quiz
        case flashcards
    }

    var dueCount: Int = 0
    let onSelect: (Entry) -> Void

    var body: some View {
        HStack(spacing: 6) {
            item(.notes, icon: .notes, title: L10n.t("lesson.nav.notes", locale: .resolved()))
            item(.quiz, icon: .quiz, title: L10n.t("lesson.nav.quiz", locale: .resolved()))
            item(.flashcards, icon: .cards, title: L10n.t("lesson.nav.flashcards", locale: .resolved()))
                .overlay(alignment: .topTrailing) {
                    if dueCount > 0 {
                        Text("\(dueCount)")
                            .font(MicaboFont.ui(11, weight: .heavy))
                            .foregroundStyle(MicaboColor.onInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MicaboColor.wrong, in: Capsule())
                            .offset(x: -8, y: 2)
                    }
                }
        }
        .padding(6)
        .micaboGlass(in: Capsule(), interactive: true)
        .padding(.horizontal, 32)
    }

    private func item(_ entry: Entry, icon: MicaboIcon, title: String) -> some View {
        Button {
            onSelect(entry)
        } label: {
            VStack(spacing: 2) {
                MicaboIconView(icon: icon, size: 30)
                Text(title)
                    .font(MicaboFont.ui(12, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }
}
