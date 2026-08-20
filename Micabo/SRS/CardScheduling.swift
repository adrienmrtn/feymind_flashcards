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
}
