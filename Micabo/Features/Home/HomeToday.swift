import SwiftData
import SwiftUI

// MARK: - Aujourd'hui

/// Ce que l'app sait de la journée, et la seule chose qu'on en tire : **ce qu'elle propose**.
/// Tout se lit dans ce que l'app sait déjà — la séance de révision du calendrier, les cartes
/// dues, la leçon en cours, la série —, rien ne vient d'un serveur.
struct HomeDay: Equatable {
    /// Les cartes dues, toutes leçons confondues.
    var dueCount = 0
    var hasCourses = false
    /// La leçon en cours : son titre (`nil` sans leçon ouverte).
    var lessonTitle: String?
    /// La leçon a avancé aujourd'hui : terminée aujourd'hui, ou ouverte et travaillée.
    var lessonAdvancedToday = false
    /// Un vrai geste d'étude a allumé la journée (`StudyStreak`).
    var studiedToday = false
    /// La séance de révision du calendrier qui reste à faire aujourd'hui (`HomeSession.next`).
    var session: HomeSession?
    /// L'étape où la leçon en cours attend, et son titre (`nil` une fois la leçon terminée).
    var lessonStep: Int?
    var lessonStepTitle: String?
    /// Au moins une étape de la leçon est faite : Mika dit « On reprend », pas « On commence ».
    var lessonStarted = false
    /// Les leçons qui ont des cartes dues.
    var dueLessons = 0

    /// **Ce que la journée propose** (lot 10, HOME.md § 1), dans l'ordre : la séance posée au
    /// calendrier — c'est le plan de l'élève —, puis les cartes dues, puis la leçon en cours ;
    /// une journée déjà travaillée où il ne reste rien est faite ; sinon rien n'est prévu.
    /// L'élève sans leçon, lui, commence par en créer une.
    enum Proposal: String, Equatable, CaseIterable {
        case session
        case cards
        case lesson
        case done
        case open
        case newcomer
    }

    var proposal: Proposal {
        guard hasCourses else { return .newcomer }
        if session != nil { return .session }
        if dueCount > 0 { return .cards }
        let lessonWaits = lessonTitle != nil && lessonStep != nil
        if lessonWaits && !lessonAdvancedToday { return .lesson }
        if studiedToday { return .done }
        if lessonWaits { return .lesson }
        return .open
    }
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

/// **Le prochain examen**, tel que la pastille de la Home l'annonce.
struct HomeExam: Equatable {
    var name: String
    var daysLeft: Int
    /// La maîtrise des cartes de l'examen, sur cent ; `nil` sans carte. La Home ne l'écrit
    /// plus : elle vit dans le Calendrier.
    var readiness: Int?
}

/// **Ce que la Home a lu de la journée**, une fois par changement, et non à chaque dessin : la
/// journée, la leçon à rouvrir, le prénom, le prochain examen.
struct HomeSnapshot: Equatable {
    var day = HomeDay()
    /// La leçon ouverte le plus récemment (`ResumeTarget.pick`).
    var resumeID: UUID?
    var name: String?
    var greeting: HomeGreeting.Moment = .day
    var exam: HomeExam?
    var examID: UUID?
    var examDate: Date?
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

/// **« {n} cartes à réviser »** : les cartes dues, leçon après leçon, dans la série de cartes de
/// la leçon (`LessonCardsRun`). « Suivant » passe à la leçon d'après.
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
            withAnimation(MicaboMotion.gentle) { position += 1 }
        }
    }
}

// MARK: - Quiz éclair

/// **« Quiz éclair »** : cinq questions sur la dernière leçon ouverte, dans le quiz de la
/// leçon. Chaque réponse rapporte son XP, comme ailleurs.
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
            title: MicaboName.quickQuiz.text(),
            circleID: nil,
            onClose: { dismiss() }
        )
    }
}
