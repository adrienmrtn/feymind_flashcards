import Foundation
import SwiftData

/// Répartition des cartes à réviser, affichée en haut des sessions.
struct StudyCounts: Equatable {
    var newCards: Int = 0
    var learning: Int = 0
    var review: Int = 0

    var total: Int { newCards + learning + review }

    static let empty = StudyCounts()
}

/// Le budget de cartes neuves **du jour**, partagé par toutes les sessions.
///
/// Une révision depuis un cours et l'onglet Réviser lisent les mêmes faits
/// (`ReviewLog.stateBefore == .new` aujourd'hui). Sans ça, chaque écran se
/// servirait un plafond neuf.
enum DailyNewQuota {
    static let sliderCap = 60

    static func introducedToday(
        from logs: [ReviewLog],
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> Int {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return logs.filter { log in
            log.stateBeforeRaw == CardState.new.rawValue
                && log.reviewedAt >= start
                && log.reviewedAt < end
        }.count
    }

    static func remaining(
        introduced: Int,
        dailyMinutes: Int = OnboardingPreferences.dailyMinutes
    ) -> Int {
        max(0, DailyLoad.newCardsPerDay(dailyMinutes: dailyMinutes) - max(0, introduced))
    }

    static func remaining(
        logs: [ReviewLog],
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared,
        dailyMinutes: Int = OnboardingPreferences.dailyMinutes
    ) -> Int {
        remaining(introduced: introducedToday(from: logs, now: now, calendar: calendar), dailyMinutes: dailyMinutes)
    }

    static func sliderMax(rhythm: Int) -> Int {
        max(20, min(sliderCap, max(rhythm * 2, rhythm)))
    }

    /// Un override vient du curseur ; sinon on sert le reste du rythme.
    static func sessionLimit(introduced: Int, override: Int? = nil, dailyMinutes: Int = OnboardingPreferences.dailyMinutes) -> Int {
        if let override { return max(0, override) }
        return remaining(introduced: introduced, dailyMinutes: dailyMinutes)
    }
}

enum StudyQueueBuilder {
    struct Limits {
        var newPerSession: Int
        var reviewsPerSession: Int

        static let `default` = Limits(newPerSession: 20, reviewsPerSession: 200)
        static let unlimited = Limits(newPerSession: .max, reviewsPerSession: .max)

        /// Plafond issu du rythme quotidien choisi à l'inscription. Les révisions
        /// dues ne sont pas rationnées, seule l'introduction de cartes neuves l'est.
        static func daily(
            minutes: Int = OnboardingPreferences.dailyMinutes,
            newRemaining: Int? = nil
        ) -> Limits {
            Limits(
                newPerSession: newRemaining ?? DailyLoad.newCardsPerDay(dailyMinutes: minutes),
                reviewsPerSession: .max
            )
        }
    }

    /// Ordonne les cartes comme Anki : apprentissage en retard, puis révisions, puis nouvelles.
    ///
    /// Les cartes sous échéance d'examen passent **devant** les autres neuves, mais elles
    /// restent dans le plafond du jour. Sans ça, un cours rattaché à deux examens vidait
    /// tout le paquet d'un coup, puis la session suivante ressortait les mêmes cartes.
    static func build(
        from cards: [Flashcard],
        now: Date = Date(),
        limits: Limits = .default,
        deadlines: ExamDeadlines = .empty
    ) -> [Flashcard] {
        let due = cards.filter { $0.isDue(at: now) }

        let learning = due
            .filter { $0.state == .learning || $0.state == .relearning }
            .sorted { $0.dueDate < $1.dueDate }

        let reviews = due
            .filter { $0.state == .review }
            .sorted { byDeadline(deadlines.deadline(for: $0), $0.dueDate, deadlines.deadline(for: $1), $1.dueDate) }
            .prefix(limits.reviewsPerSession)

        let byPosition: (Flashcard, Flashcard) -> Bool = {
            ($0.position, $0.createdAt) < ($1.position, $1.createdAt)
        }
        let newCards = due.filter { $0.state == .new }
        let examNewCards = newCards.filter { deadlines.covers($0) }.sorted(by: byPosition)
        let otherNewCards = newCards.filter { !deadlines.covers($0) }.sorted(by: byPosition)
        let introduced = Array((examNewCards + otherNewCards).prefix(limits.newPerSession))

        return learning + Array(reviews) + introduced
    }

    /// Une carte sous échéance passe devant, et l'échéance la plus proche devant les autres.
    /// À égalité, l'ordre reste celui d'Anki : la plus en retard d'abord.
    private static func byDeadline(
        _ firstDeadline: Date?,
        _ firstDue: Date,
        _ secondDeadline: Date?,
        _ secondDue: Date
    ) -> Bool {
        switch (firstDeadline, secondDeadline) {
        case (.some(let first), .some(let second)):
            return first == second ? firstDue < secondDue : first < second
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return firstDue < secondDue
        }
    }

    static func counts(
        for cards: [Flashcard],
        now: Date = Date(),
        limits: Limits = .default,
        deadlines: ExamDeadlines = .empty
    ) -> StudyCounts {
        let queue = build(from: cards, now: now, limits: limits, deadlines: deadlines)
        return StudyCounts(
            newCards: queue.filter { $0.state == .new }.count,
            learning: queue.filter { $0.state == .learning || $0.state == .relearning }.count,
            review: queue.filter { $0.state == .review }.count
        )
    }
}

/// Ce qu'un écran de cours affiche **avant** d'avoir lu les journaux et les examens.
///
/// Le premier cadre d'une fiche ne peut pas attendre trois `@Query` : c'est ce délai, plus
/// le fondu des onglets, qui rendait chaque ouverture tardive. On compte donc les cartes
/// dues du cours tout de suite, et on affine ensuite avec le plafond du jour.
struct CourseDuePreview: Equatable {
    var dueCount: Int
    var heldBackNewCards: Int
    var examName: String?

    /// Assez juste pour le premier cadre : les cartes dues, sans rationnement.
    static func immediate(from cards: [Flashcard], now: Date = Date()) -> CourseDuePreview {
        CourseDuePreview(
            dueCount: cards.filter { $0.isDue(at: now) }.count,
            heldBackNewCards: 0,
            examName: nil
        )
    }

    /// La file réelle, une fois la page déjà à l'écran.
    static func scheduled(
        from cards: [Flashcard],
        courseID: UUID,
        in context: ModelContext,
        now: Date = Date()
    ) -> CourseDuePreview {
        let logs = (try? context.fetch(FetchDescriptor<ReviewLog>())) ?? []
        let exams = (try? context.fetch(FetchDescriptor<Exam>())) ?? []
        let courses = CourseRepository.allCourses(in: context)
        let due = StudyQueueBuilder.build(
            from: cards,
            now: now,
            limits: .daily(newRemaining: DailyNewQuota.remaining(logs: logs, now: now)),
            deadlines: ExamDeadlines.active(exams: exams, courses: courses, now: now)
        )
        let dueNew = due.filter { $0.state == .new }.count
        let allDueNew = cards.filter { $0.isDue(at: now) && $0.state == .new }.count

        return CourseDuePreview(
            dueCount: due.count,
            heldBackNewCards: max(0, allDueNew - dueNew),
            examName: nearestExamName(exams: exams, courseID: courseID, now: now)
        )
    }

    /// L'examen planifié le plus proche qui porte sur ce cours.
    static func nearestExamName(
        exams: [Exam],
        courseID: UUID,
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> String? {
        let today = calendar.startOfDay(for: now)
        return exams
            .filter { exam in
                exam.isPlanned
                    && exam.courseIDs.contains(courseID)
                    && calendar.startOfDay(for: exam.date) >= today
            }
            .sorted { $0.date < $1.date }
            .first
            .map { exam in
                let name = exam.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? "Examen" : name
            }
    }
}
