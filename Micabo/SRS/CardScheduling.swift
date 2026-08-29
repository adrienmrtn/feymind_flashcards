import Foundation

/// Photographie de l'état de répétition espacée d'une carte, prise avant de la noter.
///
/// C'est ce qui permet d'annuler une note en session : on ne recalcule rien à l'envers,
/// on remet exactement les valeurs d'avant. Recalculer une note inverse serait faux dès
/// que le planificateur a de l'aléatoire (la dispersion des échéances) ou de l'historique
/// (les paliers d'apprentissage).
struct CardScheduling: Equatable {
    var state: CardState
    var dueDate: Date
    var intervalDays: Double
    var easeFactor: Double
    var repetitions: Int
    var lapses: Int
    var stepIndex: Int
    var lastReviewedAt: Date?
    var updatedAt: Date
    var isSuspended: Bool

    init(card: Flashcard) {
        state = card.state
        dueDate = card.dueDate
        intervalDays = card.intervalDays
        easeFactor = card.easeFactor
        repetitions = card.repetitions
        lapses = card.lapses
        stepIndex = card.stepIndex
        lastReviewedAt = card.lastReviewedAt
        updatedAt = card.updatedAt
        isSuspended = card.isSuspended
    }

    func restore(on card: Flashcard) {
        card.state = state
        card.dueDate = dueDate
        card.intervalDays = intervalDays
        card.easeFactor = easeFactor
        card.repetitions = repetitions
        card.lapses = lapses
        card.stepIndex = stepIndex
        card.lastReviewedAt = lastReviewedAt
        card.updatedAt = updatedAt
        card.isSuspended = isSuspended
    }

    /// L'état que le planificateur lit, sans passer par SwiftData.
    var snapshot: SM2CardSnapshot {
        SM2CardSnapshot(
            state: state,
            intervalDays: intervalDays,
            easeFactor: easeFactor,
            repetitions: repetitions,
            lapses: lapses,
            stepIndex: stepIndex,
            dueDate: dueDate
        )
    }

    /// Applique une note en mémoire. La carte SwiftData n'est pas touchée : c'est
    /// `restore` qui l'écrit, au moment où la session pose le paquet.
    mutating func apply(_ outcome: SM2Outcome, at date: Date) {
        state = outcome.state
        dueDate = outcome.dueDate
        intervalDays = outcome.intervalDays
        easeFactor = outcome.easeFactor
        repetitions = outcome.repetitions
        lapses = outcome.lapses
        stepIndex = outcome.stepIndex
        lastReviewedAt = date
        updatedAt = date
    }
}
