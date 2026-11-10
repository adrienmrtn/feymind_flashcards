import SwiftData
import SwiftUI

// MARK: - Aujourd'hui

/// Ce que l'app sait de la journée, et la seule chose qu'on en tire : **la prochaine étape**.
/// Tout se lit dans ce que l'app sait déjà — la séance de révision du calendrier, les cartes
/// dues, la leçon en cours, la série —, rien ne vient d'un serveur.
struct HomeDay: Equatable {
    /// Les cartes dues, toutes leçons confondues.
    var dueCount = 0
    /// Les cartes notées aujourd'hui.
    var reviewedToday = 0
    var hasCourses = false
    /// La leçon en cours : son titre et le cercle où elle attend (`nil` une fois terminée).
    var lessonTitle: String?
    var lessonCircle: String?
    /// La leçon a avancé aujourd'hui : terminée aujourd'hui, ou ouverte et travaillée.
    var lessonAdvancedToday = false
    /// Un vrai geste d'étude a allumé la journée (`StudyStreak`).
    var studiedToday = false
    /// La séance de révision du calendrier qui reste à faire aujourd'hui (`HomeSession.next`).
    var session: HomeSession?

    /// Une étape de la journée. Les noms partent tels quels dans `home_plan_tapped`.
    enum Step: String, Equatable {
        /// Écrire une leçon : la première, ou la suivante.
        case create
        /// Reprendre la leçon en cours, au cercle où elle attend.
        case lesson
        /// Réviser les cartes dues.
        case cards
        /// Mener la séance de révision que le calendrier a posée aujourd'hui.
        case session
    }

    private var hasOpenLesson: Bool { lessonTitle != nil && lessonCircle != nil }

    /// **La prochaine chose à faire**, et la seule que le plan du jour met en avant : la séance
    /// prévue au calendrier d'abord — c'est le plan de l'élève —, puis la leçon en cours tant
    /// qu'elle n'a pas avancé aujourd'hui, puis les cartes dues, puis la leçon ; sans leçon,
    /// en écrire une.
    var primary: Step {
        guard hasCourses else { return .create }
        if session != nil { return .session }
        if hasOpenLesson && !lessonAdvancedToday { return .lesson }
        if dueCount > 0 { return .cards }
        if hasOpenLesson { return .lesson }
        return .create
    }

    /// **Une seconde ligne, au plus** : ce qui reste d'utile à côté de l'étape mise en avant.
    var secondary: Step? {
        switch primary {
        case .session: dueCount > 0 ? .cards : (hasOpenLesson ? .lesson : nil)
        case .lesson: dueCount > 0 ? .cards : nil
        case .cards: hasOpenLesson ? .lesson : nil
        case .create: dueCount > 0 ? .cards : nil
        }
    }
}

/// Où un geste du plan a été fait : le grand bouton, ou la ligne dessous.
enum HomeSlot: String {
    case hero
    case secondary
}

/// **La séance de révision d'aujourd'hui** que Home propose : une ligne `revision` de l'agenda
/// (`StudyPlan.today`), pas faite, pas encore finie.
struct HomeSession: Equatable {
    var eventID: UUID?
    var courseID: UUID?
    var title: String
    var startMinute: Int
    var endMinute: Int
    /// L'examen que la séance prépare, s'il y en a un.
    var examName: String?

    var minutes: Int { max(0, endMinute - startMinute) }

    /// La première séance de révision du jour qui n'est ni faite ni passée.
    static func next(in items: [AgendaItem], now: Date, examNames: [UUID: String] = [:], calendar: Calendar = MicaboCalendar.shared) -> HomeSession? {
        let minute = CalendarTime.minute(of: now, calendar: calendar)
        guard let item = items.first(where: { item in
            item.kind == .revision && !item.isDone && item.startMinute != nil && (item.endMinute ?? 0) > minute
        }), let start = item.startMinute, let end = item.endMinute else { return nil }
        return HomeSession(
            eventID: item.eventID,
            courseID: item.courseID,
            title: item.title,
            startMinute: start,
            endMinute: end,
            examName: item.examID.flatMap { examNames[$0] }
        )
    }
}

/// **Le prochain examen**, tel que le plan du jour l'annonce.
struct HomeExam: Equatable {
    var name: String
    var daysLeft: Int
    /// La maîtrise des cartes de l'examen, sur cent ; `nil` sans carte.
    var readiness: Int?
}

/// Une leçon récente, pour la rangée « Mes leçons ».
struct HomeLessonCard: Equatable, Identifiable {
    var id: UUID
    var title: String
    var icon: MicaboIcon
    var tone: LessonTone
    var percent: Int

    /// Les leçons ouvertes le plus récemment, puis les plus récentes.
    static func recent(_ courses: [Course], limit: Int = 5) -> [HomeLessonCard] {
        courses
            .filter(\.isLesson)
            .sorted { ($0.lastOpenedAt ?? $0.createdAt) > ($1.lastOpenedAt ?? $1.createdAt) }
            .prefix(limit)
            .map { course in
                HomeLessonCard(
                    id: course.id,
                    title: course.title,
                    icon: course.icon,
                    tone: course.tone,
                    percent: ResumeTarget.target(for: course).percent
                )
            }
    }
}

/// **Ce que le plan du jour lit du calendrier** : le prochain examen, ce qui reste à l'agenda
/// d'aujourd'hui, et les leçons récentes.
struct HomePlan: Equatable {
    var exam: HomeExam?
    /// Ce qui reste à faire aujourd'hui, la séance du plan mise à part (`upcoming`).
    var agenda: [AgendaItem] = []
    var lessons: [HomeLessonCard] = []

    /// Trois lignes au plus : ce qui dure toute la journée et n'est pas fait, puis ce qui n'est
    /// pas encore fini, sans les séances de concentration menées ni la séance déjà proposée.
    static func upcoming(_ items: [AgendaItem], now: Date, excluding session: HomeSession?, limit: Int = 3, calendar: Calendar = MicaboCalendar.shared) -> [AgendaItem] {
        let minute = CalendarTime.minute(of: now, calendar: calendar)
        return Array(items.filter { item in
            guard item.kind != .focus, !item.isDone else { return false }
            if let session, item.kind == .revision, item.eventID == session.eventID { return false }
            return item.isAllDay || (item.endMinute ?? 0) > minute
        }.prefix(limit))
    }
}

/// **L'anneau de l'objectif du jour** : le bleu de la marque sur un creux, l'éclair jaune du
/// crayon au milieu, une coche une fois atteint. Il se remplit à l'arrivée, puis suit chaque
/// gain.
struct HomeGoalRing: View {
    let progress: Double
    let motion: HomeMotion
    var size: CGFloat = 58
    var lineWidth: CGFloat = 7

    @State private var filled = false

    var body: some View {
        let target = max(0, min(1, progress))
        let shown = filled || !motion.entrance ? target : 0
        ZStack {
            Circle().stroke(HomePalette.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(
                    target >= 1 ? AnyShapeStyle(MicaboColor.correct) : AnyShapeStyle(MicaboStage.buttonFill),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: target >= 1 ? "checkmark" : "bolt.fill")
                .font(.system(size: size * 0.32, weight: .black))
                .foregroundStyle(target >= 1 ? MicaboColor.correct : HomePalette.bolt)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: shown)
        .onAppear {
            guard motion.entrance, !filled else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { filled = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Les outils

/// Les outils de Home, hors de la leçon.
enum HomeTool: CaseIterable {
    case scan
    case quiz
    case timer
    case league

    var icon: MicaboIcon {
        switch self {
        case .scan: .photo
        case .quiz: .quiz
        case .timer: .alarm
        case .league: .trophy
        }
    }

    var tone: LessonTone {
        switch self {
        case .scan: .blue
        case .quiz: .pink
        case .timer: .mint
        case .league: .yellow
        }
    }

    var title: String {
        switch self {
        case .scan: L10n.t("ios.kx.tools.scan.title", locale: .resolved())
        case .quiz: L10n.t("ios.kx.tools.quiz.title", locale: .resolved())
        case .timer: L10n.t("ios.kx.tools.timer.title", locale: .resolved())
        case .league: L10n.t("ios.kx.tools.league.title", locale: .resolved())
        }
    }
}

/// **Les outils, en raccourcis légers** : une seule carte, quatre icônes sur leur pastille et
/// leur nom dessous, sur deux lignes au plus. Ils restent sous la main sans peser autant que
/// le plan du jour.
struct HomeToolsCard: View {
    let onTool: (HomeTool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            ForEach(HomeTool.allCases, id: \.self) { tool in
                Button { onTool(tool) } label: { shortcut(tool) }
                    .buttonStyle(HomePressStyle(scale: 0.92, feedback: .soft))
                    .accessibilityLabel(Text(tool.title))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 14)
        .homeCard(radius: MicaboStage.tileRadius)
    }

    private func shortcut(_ tool: HomeTool) -> some View {
        VStack(spacing: 7) {
            MicaboIconView(icon: tool.icon, size: 26)
                .frame(width: 44, height: 44)
                .background(tool.tone.pale, in: Circle())
            Text(tool.title)
                .font(MicaboFont.ui(12.5, weight: .heavy))
                .foregroundStyle(HomePalette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Les cartes dues

/// Les cartes dues de toutes les leçons, comptées comme `LessonSession.dueCards`.
enum DueReview {
    static func dueCount(of course: Course, now: Date = Date()) -> Int {
        course.cards.filter { !$0.isSuspended && $0.state != .new && $0.dueDate <= now }.count
    }

    /// Les leçons qui ont des cartes dues, la plus chargée d'abord.
    static func courses(_ courses: [Course], now: Date = Date()) -> [Course] {
        courses
            .map { ($0, dueCount(of: $0, now: now)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }
}

/// **« {n} cartes à réviser »** : les cartes dues, leçon après leçon, dans la série de
/// flashcards de la leçon (`LessonCardsRun`). « Suivant » passe à la leçon d'après.
struct DueCardsReview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [LessonSession]
    @State private var position = 0

    init(courses: [Course]) {
        _sessions = State(initialValue: courses.map { LessonSession(course: $0) })
    }

    var body: some View {
        Group {
            if sessions.indices.contains(position) {
                let session = sessions[position]
                LessonCardsRun(
                    session: session,
                    cards: session.dueCards(),
                    onClose: { dismiss() },
                    onDone: nextLesson
                )
                .id(position)
                .transition(.move(edge: .trailing))
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
    }

    /// « Suivant » vers la leçon d'après ; rien sur la dernière, qui se termine par « Terminer ».
    private var nextLesson: (() -> Void)? {
        guard position + 1 < sessions.count else { return nil }
        return {
            withAnimation(.spring(duration: 0.4)) { position += 1 }
        }
    }
}

// MARK: - Quiz éclair

/// **« Quiz éclair »** (§ 1.4) : cinq questions sur la dernière leçon ouverte, dans le quiz de
/// la leçon. Chaque réponse rapporte son XP, comme ailleurs.
struct QuickQuizSheet: View {
    static let count = 5

    @Environment(\.dismiss) private var dismiss
    @State private var session: LessonSession
    @State private var questions: [QuizQuestion]

    init(course: Course) {
        let session = LessonSession(course: course)
        _session = State(initialValue: session)
        _questions = State(initialValue: Array(session.fullQuiz(attempt: Int.random(in: 1...100_000)).prefix(Self.count)))
    }

    var body: some View {
        LessonQuizView(
            session: session,
            questions: questions,
            title: L10n.t("ios.kx.tools.quiz.title", locale: .resolved()),
            circleID: nil,
            onClose: { dismiss() }
        )
    }
}
