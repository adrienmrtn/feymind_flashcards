import Foundation

/// Répartition des cartes à réviser, affichée en haut des sessions.
struct StudyCounts: Equatable {
    var newCards: Int = 0
    var learning: Int = 0
    var review: Int = 0

    var total: Int { newCards + learning + review }

    static let empty = StudyCounts()
}

enum StudyQueueBuilder {
    struct Limits {
        var newPerSession: Int
        var reviewsPerSession: Int

        static let `default` = Limits(newPerSession: 20, reviewsPerSession: 200)
        static let unlimited = Limits(newPerSession: .max, reviewsPerSession: .max)

        /// Plafond issu du rythme quotidien choisi à l'inscription : c'est ce qui rend le
        /// curseur de l'onboarding utile. Les révisions dues ne sont pas rationnées, seule
        /// l'introduction de cartes neuves l'est.
        static func daily(minutes: Int = OnboardingPreferences.dailyMinutes) -> Limits {
            Limits(
                newPerSession: DailyLoad.newCardsPerDay(dailyMinutes: minutes),
                reviewsPerSession: .max
            )
        }
    }

    /// Ordonne les cartes comme Anki : apprentissage en retard, puis révisions, puis nouvelles.
    ///
    /// Les cartes sous échéance d'examen font exception au plafond de cartes neuves. Sans
    /// cette exception, le plan annoncé à la confirmation serait un mensonge : il promet
    /// quarante cartes aujourd'hui, et le rythme quotidien n'en laisserait passer que huit.
    /// Le plafond garde tout son sens hors examen, où il n'y a pas de date à tenir.
    static func build(
        from cards: [Flashcard],
        now: Date = Date(),
        limits: Limits = .default,
        deadlines: ExamDeadlines = .none
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
        let otherNewCards = newCards
            .filter { !deadlines.covers($0) }
            .sorted(by: byPosition)
            .prefix(limits.newPerSession)

        return learning + Array(reviews) + examNewCards + Array(otherNewCards)
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
        deadlines: ExamDeadlines = .none
    ) -> StudyCounts {
        let queue = build(from: cards, now: now, limits: limits, deadlines: deadlines)
        return StudyCounts(
            newCards: queue.filter { $0.state == .new }.count,
            learning: queue.filter { $0.state == .learning || $0.state == .relearning }.count,
            review: queue.filter { $0.state == .review }.count
        )
    }
}
