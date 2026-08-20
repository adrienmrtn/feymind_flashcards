import Foundation
import Observation
import SwiftData

enum StudySource {
    case course(Course)
    case allDue
    case cards([Flashcard])
}

/// Pilote une session de révision : file d'attente, réponses, statistiques.
@Observable
final class StudySession {
    struct Entry {
        var card: Flashcard
        /// Instant à partir duquel la carte peut réapparaître dans la session.
        var availableAt: Date
    }

    /// Une carte replanifiée à moins de 20 minutes revient dans la même session, comme dans Anki.
    private let learnAheadWindow: TimeInterval = 20 * 60

    private(set) var pending: [Entry] = []
    private(set) var current: Flashcard?
    private(set) var isRevealed = false
    private(set) var initialCount = 0
    private(set) var answeredCount = 0
    private(set) var againCount = 0
    private(set) var goodCount = 0
    private(set) var startedAt = Date()
    private(set) var isFinished = false

    private var context: ModelContext?

    var counts: StudyCounts {
        StudyCounts(
            newCards: pending.filter { $0.card.state == .new }.count,
            learning: pending.filter { $0.card.state == .learning || $0.card.state == .relearning }.count,
            review: pending.filter { $0.card.state == .review }.count
        )
    }

    var progress: Double {
        guard initialCount > 0 else { return 0 }
        return min(1, Double(answeredCount) / Double(max(initialCount, answeredCount + pending.count)))
    }

    var accuracy: Double {
        guard answeredCount > 0 else { return 0 }
        return Double(answeredCount - againCount) / Double(answeredCount)
    }

    var elapsed: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    /// Aperçus « 1 min / 10 min / 1 j / 4 j » sous les boutons.
    var previewLabels: [ReviewRating: String] {
        guard let current else { return [:] }
        return SM2Scheduler.previewLabels(for: SM2CardSnapshot(card: current))
    }

    // MARK: - Cycle de vie

    func start(with cards: [Flashcard], context: ModelContext, now: Date = Date()) {
        guard current == nil, !isFinished else { return }

        self.context = context
        startedAt = now

        let queue = StudyQueueBuilder.build(from: cards, now: now, limits: .unlimited)
        let usable = queue.isEmpty ? earlyReviewFallback(from: cards) : queue

        pending = usable.map { Entry(card: $0, availableAt: min($0.dueDate, now)) }
        initialCount = pending.count
        advance()
    }

    /// Quand rien n'est dû, on propose quand même les cartes les plus proches de l'échéance.
    private func earlyReviewFallback(from cards: [Flashcard]) -> [Flashcard] {
        cards
            .filter { !$0.isSuspended }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(20)
            .map { $0 }
    }

    func reveal() {
        guard current != nil else { return }
        isRevealed = true
    }

    func answer(_ rating: ReviewRating, now: Date = Date()) {
        guard let card = current else { return }

        let outcome = SM2Scheduler.schedule(snapshot: SM2CardSnapshot(card: card), rating: rating, now: now)
        card.apply(outcome, at: now)
        try? context?.save()

        answeredCount += 1
        if rating == .again {
            againCount += 1
        } else {
            goodCount += 1
        }

        if outcome.dueDate.timeIntervalSince(now) <= learnAheadWindow {
            pending.append(Entry(card: card, availableAt: outcome.dueDate))
        }

        current = nil
        isRevealed = false
        advance()
    }

    /// Repousse la carte courante à la fin de la file sans la noter.
    func skip(now: Date = Date()) {
        guard let card = current else { return }
        pending.append(Entry(card: card, availableAt: now.addingTimeInterval(60)))
        current = nil
        isRevealed = false
        advance()
    }

    func suspendCurrent() {
        guard let card = current else { return }
        card.isSuspended = true
        try? context?.save()
        current = nil
        isRevealed = false
        advance()
    }

    private func advance() {
        guard !pending.isEmpty else {
            current = nil
            isFinished = true
            return
        }

        pending.sort { $0.availableAt < $1.availableAt }
        let entry = pending.removeFirst()
        current = entry.card
        isRevealed = false
    }

    /// Cartes affichées en arrière-plan de la pile.
    func upcoming(_ limit: Int) -> [Flashcard] {
        pending
            .sorted { $0.availableAt < $1.availableAt }
            .prefix(limit)
            .map(\.card)
    }
}
