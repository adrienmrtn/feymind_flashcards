import Foundation
import SwiftData

/// États d'une carte, calqués sur ceux d'Anki.
enum CardState: String, Codable, CaseIterable {
    case new
    case learning
    case review
    case relearning

    var label: String {
        switch self {
        case .new: "Nouvelle"
        case .learning: "Apprentissage"
        case .review: "Révision"
        case .relearning: "Réapprentissage"
        }
    }
}

/// Les quatre boutons de maîtrise d'Anki.
enum ReviewRating: Int, Codable, CaseIterable, Identifiable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .again: "À revoir"
        case .hard: "Difficile"
        case .good: "Correct"
        case .easy: "Facile"
        }
    }

    var shortLabel: String {
        switch self {
        case .again: "Revoir"
        case .hard: "Difficile"
        case .good: "Correct"
        case .easy: "Facile"
        }
    }

    var systemImage: String {
        switch self {
        case .again: "arrow.counterclockwise"
        case .hard: "tortoise.fill"
        case .good: "checkmark"
        case .easy: "hare.fill"
        }
    }
}

@Model
final class Flashcard {
    var id: UUID = UUID()
    var front: String = ""
    var back: String = ""
    var hint: String?
    var position: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isSuspended: Bool = false

    // État de répétition espacée (SM-2)
    var stateRaw: String = CardState.new.rawValue
    var dueDate: Date = Date()
    /// Intervalle courant en jours. Vaut 0 tant que la carte est en apprentissage.
    var intervalDays: Double = 0
    var easeFactor: Double = SM2Scheduler.Configuration.default.startingEase
    var repetitions: Int = 0
    var lapses: Int = 0
    /// Position dans les paliers d'apprentissage / réapprentissage.
    var stepIndex: Int = 0
    var lastReviewedAt: Date?

    var course: Course?

    @Relationship(deleteRule: .cascade, inverse: \ReviewLog.card)
    var logs: [ReviewLog]? = []

    init(
        front: String,
        back: String,
        hint: String? = nil,
        position: Int = 0,
        course: Course? = nil
    ) {
        self.id = UUID()
        self.front = front
        self.back = back
        self.hint = hint
        self.position = position
        self.createdAt = Date()
        self.updatedAt = Date()
        self.dueDate = Date()
        self.course = course
        self.logs = []
    }

    var state: CardState {
        get { CardState(rawValue: stateRaw) ?? .new }
        set { stateRaw = newValue.rawValue }
    }

    func isDue(at date: Date = Date()) -> Bool {
        guard !isSuspended else { return false }
        return dueDate <= date
    }

    /// Une carte « mûre » a un intervalle d'au moins 21 jours, comme dans Anki.
    var isMature: Bool {
        intervalDays >= 21
    }

    /// Applique le résultat calculé par le planificateur.
    func apply(_ outcome: SM2Outcome, at date: Date) {
        let previousInterval = intervalDays
        let previousState = state

        state = outcome.state
        dueDate = outcome.dueDate
        intervalDays = outcome.intervalDays
        easeFactor = outcome.easeFactor
        repetitions = outcome.repetitions
        lapses = outcome.lapses
        stepIndex = outcome.stepIndex
        lastReviewedAt = date
        updatedAt = date

        let log = ReviewLog(
            reviewedAt: date,
            rating: outcome.rating,
            stateBefore: previousState,
            previousIntervalDays: previousInterval,
            newIntervalDays: outcome.intervalDays,
            easeAfter: outcome.easeFactor
        )
        // On ne renseigne qu'un seul côté : SwiftData maintient la relation inverse.
        logs = (logs ?? []) + [log]
    }

    /// Réinitialise la programmation sans supprimer la carte.
    func resetScheduling() {
        state = .new
        dueDate = Date()
        intervalDays = 0
        easeFactor = SM2Scheduler.Configuration.default.startingEase
        repetitions = 0
        lapses = 0
        stepIndex = 0
        lastReviewedAt = nil
        updatedAt = Date()
    }
}

@Model
final class ReviewLog {
    var id: UUID = UUID()
    var reviewedAt: Date = Date()
    var ratingRaw: Int = ReviewRating.good.rawValue
    var stateBeforeRaw: String = CardState.new.rawValue
    var previousIntervalDays: Double = 0
    var newIntervalDays: Double = 0
    var easeAfter: Double = 2.5
    var card: Flashcard?

    init(
        reviewedAt: Date,
        rating: ReviewRating,
        stateBefore: CardState,
        previousIntervalDays: Double,
        newIntervalDays: Double,
        easeAfter: Double
    ) {
        self.id = UUID()
        self.reviewedAt = reviewedAt
        self.ratingRaw = rating.rawValue
        self.stateBeforeRaw = stateBefore.rawValue
        self.previousIntervalDays = previousIntervalDays
        self.newIntervalDays = newIntervalDays
        self.easeAfter = easeAfter
    }

    var rating: ReviewRating {
        ReviewRating(rawValue: ratingRaw) ?? .good
    }
}
