import Foundation
import Observation
import SwiftData

enum StudySource {
    case course(Course)
    case allDue
    case cards([Flashcard])

    /// Clé de reprise. Une sélection ponctuelle de cartes ne se reprend pas : on ne
    /// saurait pas la reconstituer de façon fiable au lancement suivant.
    var persistenceKey: String? {
        switch self {
        case .allDue:
            return "allDue"
        case .course(let course):
            return "course:\(course.id.uuidString)"
        case .cards:
            return nil
        }
    }
}

/// Deux façons de réviser, et il ne faut pas les confondre : la session normale écrit
/// dans le planning, l'entraînement libre n'y touche pas.
enum StudyMode {
    case scheduled
    case practice

    var affectsSchedule: Bool { self == .scheduled }
}

/// Pilote une session de révision : file d'attente, réponses, statistiques.
@Observable
final class StudySession {
    struct Entry {
        var card: Flashcard
        /// Instant à partir duquel la carte peut réapparaître dans la session.
        var availableAt: Date
    }

    /// Ce qu'il faut pour revenir exactement à l'état d'avant la dernière action.
    private struct UndoStep {
        let card: Flashcard
        let scheduling: CardScheduling
        /// Le journal écrit par la note, à supprimer si on l'annule.
        var log: ReviewLog?
        let pending: [Entry]
        let answeredCount: Int
        let againCount: Int
        let goodCount: Int
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
    private(set) var mode: StudyMode = .scheduled
    private(set) var didStart = false

    private var context: ModelContext?
    private var sourceKey: String?
    private var undoStack: [UndoStep] = []

    /// Vrai dès la première note donnée : c'est ce qui active le bouton d'annulation.
    var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// La session a démarré mais n'a rien trouvé à réviser.
    var isEmpty: Bool {
        didStart && initialCount == 0
    }

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

    /// Aperçus « 1 min / 10 min / 1 j / 4 j » sous les boutons. En entraînement libre,
    /// aucune échéance ne bouge : les aperçus n'auraient rien à annoncer.
    var previewLabels: [ReviewRating: String] {
        guard mode.affectsSchedule, let current else { return [:] }
        return SM2Scheduler.previewLabels(for: SM2CardSnapshot(card: current))
    }

    // MARK: - Cycle de vie

    func start(
        with cards: [Flashcard],
        context: ModelContext,
        mode: StudyMode = .scheduled,
        sourceKey: String? = nil,
        now: Date = Date()
    ) {
        guard !didStart else { return }
        didStart = true

        self.context = context
        self.mode = mode
        self.sourceKey = mode.affectsSchedule ? sourceKey : nil
        startedAt = now

        let usable: [Flashcard]
        switch mode {
        case .scheduled:
            usable = StudyQueueBuilder.build(from: cards, now: now, limits: .daily())
        case .practice:
            // Tout le cours, dans l'ordre des cartes : on s'entraîne, on ne rattrape rien.
            usable = cards
                .filter { !$0.isSuspended }
                .sorted { ($0.position, $0.createdAt) < ($1.position, $1.createdAt) }
        }

        pending = queue(from: usable, now: now)
        initialCount = pending.count
        advance()
        persist()
    }

    /// Reprend une session interrompue à la carte près.
    func resume(
        _ snapshot: StudySessionSnapshot,
        cards: [Flashcard],
        context: ModelContext,
        now: Date = Date()
    ) {
        guard !didStart else { return }
        didStart = true

        self.context = context
        mode = .scheduled
        sourceKey = snapshot.sourceKey
        // La durée affichée en fin de session reste celle du temps réellement passé.
        startedAt = now.addingTimeInterval(-snapshot.elapsed)

        let byID = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let restored = snapshot.remainingCardIDs
            .compactMap { byID[$0] }
            .filter { !$0.isSuspended }

        pending = queue(from: restored, now: now)
        initialCount = max(snapshot.initialCount, snapshot.answeredCount + pending.count)
        answeredCount = snapshot.answeredCount
        againCount = snapshot.againCount
        goodCount = snapshot.goodCount

        advance()
        persist()
    }

    /// Conserve l'ordre reçu : `advance()` trie par disponibilité, on échelonne donc les
    /// instants d'un rien pour que la file ne se réorganise pas dans le dos du planificateur.
    private func queue(from cards: [Flashcard], now: Date) -> [Entry] {
        cards.enumerated().map { index, card in
            Entry(card: card, availableAt: now.addingTimeInterval(Double(index) - Double(cards.count)))
        }
    }

    func reveal() {
        guard current != nil else { return }
        isRevealed = true
    }

    func answer(_ rating: ReviewRating, now: Date = Date()) {
        guard let card = current else { return }

        var step = UndoStep(
            card: card,
            scheduling: CardScheduling(card: card),
            log: nil,
            pending: pending,
            answeredCount: answeredCount,
            againCount: againCount,
            goodCount: goodCount
        )

        if mode.affectsSchedule {
            let logsBefore = Set((card.logs ?? []).map(\.id))
            let outcome = SM2Scheduler.schedule(snapshot: SM2CardSnapshot(card: card), rating: rating, now: now)
            card.apply(outcome, at: now)
            try? context?.save()

            step.log = (card.logs ?? []).first { !logsBefore.contains($0.id) }

            if outcome.dueDate.timeIntervalSince(now) <= learnAheadWindow {
                pending.append(Entry(card: card, availableAt: outcome.dueDate))
            }
        } else if rating == .again {
            // En entraînement libre, une carte ratée revient à la fin du tour.
            pending.append(Entry(card: card, availableAt: now.addingTimeInterval(30)))
        }

        undoStack.append(step)

        answeredCount += 1
        if rating == .again {
            againCount += 1
        } else {
            goodCount += 1
        }

        current = nil
        isRevealed = false
        advance()
        persist()
    }

    /// Revient sur la dernière action et remet la carte exactement dans son état d'avant.
    func undo() {
        guard let step = undoStack.popLast() else { return }

        if let log = step.log {
            context?.delete(log)
        }
        step.scheduling.restore(on: step.card)
        try? context?.save()

        pending = step.pending
        answeredCount = step.answeredCount
        againCount = step.againCount
        goodCount = step.goodCount
        isFinished = false
        current = step.card
        // La réponse était sous les yeux au moment de la note : on la laisse visible.
        isRevealed = true
        persist()
    }

    /// Repousse la carte courante à la fin de la file sans la noter.
    func skip(now: Date = Date()) {
        guard let card = current else { return }
        pending.append(Entry(card: card, availableAt: now.addingTimeInterval(60)))
        current = nil
        isRevealed = false
        advance()
        persist()
    }

    /// Met la carte de côté : elle sort de la session et ne reviendra pas tant qu'on ne
    /// la réactive pas. Annulable comme une note.
    func setAsideCurrent() {
        guard let card = current else { return }

        let step = UndoStep(
            card: card,
            scheduling: CardScheduling(card: card),
            log: nil,
            pending: pending,
            answeredCount: answeredCount,
            againCount: againCount,
            goodCount: goodCount
        )

        if mode.affectsSchedule {
            card.isSuspended = true
            try? context?.save()
        }

        undoStack.append(step)
        current = nil
        isRevealed = false
        advance()
        persist()
    }

    /// À appeler après une modification de la carte affichée, pour que la file reste juste.
    func cardWasEdited() {
        try? context?.save()
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

    // MARK: - Reprise

    /// Écrit l'état après chaque action. L'entraînement libre ne se reprend pas : il ne
    /// laisse aucune trace, c'est tout l'intérêt.
    private func persist() {
        guard mode.affectsSchedule, let sourceKey else { return }

        let remaining = ([current].compactMap { $0 } + pending.map(\.card)).map(\.id)
        guard !isFinished, !remaining.isEmpty else {
            StudySessionStore.clear()
            return
        }

        StudySessionStore.save(
            StudySessionSnapshot(
                sourceKey: sourceKey,
                remainingCardIDs: remaining,
                initialCount: initialCount,
                answeredCount: answeredCount,
                againCount: againCount,
                goodCount: goodCount,
                elapsed: elapsed,
                savedAt: Date()
            )
        )
    }
}
