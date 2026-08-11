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
    }

    /// Ordonne les cartes comme Anki : apprentissage en retard, puis révisions, puis nouvelles.
    static func build(
        from cards: [Flashcard],
        now: Date = Date(),
        limits: Limits = .default
    ) -> [Flashcard] {
        let due = cards.filter { $0.isDue(at: now) }

        let learning = due
            .filter { $0.state == .learning || $0.state == .relearning }
            .sorted { $0.dueDate < $1.dueDate }

        let reviews = due
            .filter { $0.state == .review }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(limits.reviewsPerSession)

        let fresh = due
            .filter { $0.state == .new }
            .sorted { ($0.position, $0.createdAt) < ($1.position, $1.createdAt) }
            .prefix(limits.newPerSession)

        return learning + Array(reviews) + Array(fresh)
    }

    static func counts(for cards: [Flashcard], now: Date = Date(), limits: Limits = .default) -> StudyCounts {
        let queue = build(from: cards, now: now, limits: limits)
        return StudyCounts(
            newCards: queue.filter { $0.state == .new }.count,
            learning: queue.filter { $0.state == .learning || $0.state == .relearning }.count,
            review: queue.filter { $0.state == .review }.count
        )
    }
}
