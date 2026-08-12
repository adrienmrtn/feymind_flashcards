import Observation
import SwiftUI

/// État partagé du parcours d'accueil. Les réponses sont écrites au fil de l'eau
/// dans `OnboardingPreferences` : quitter l'app en cours de route ne les perd pas.
@Observable
final class OnboardingModel {
    private(set) var step: OnboardingStep = .welcome

    var goal: LearningGoal?
    var forgetsOften: Bool?
    var subjects: Set<String> = []
    var dailyMinutes = 15
    var notificationsOptIn = false

    /// Nombre de cartes que l'utilisateur peut espérer mémoriser en un an,
    /// au rythme qu'il vient de choisir.
    var projectedCardsPerYear: Int {
        LearningProjection.cardsPerYear(dailyMinutes: dailyMinutes)
    }

    func advance() {
        persist()
        guard let next = step.next else { return }
        step = next
    }

    /// Recopie les réponses dans les réglages à chaque changement d'écran :
    /// une sortie en cours de route ne perd que la question en cours.
    private func persist() {
        OnboardingPreferences.goal = goal
        OnboardingPreferences.forgetsOften = forgetsOften
        OnboardingPreferences.subjects = subjects.sorted()
        OnboardingPreferences.dailyMinutes = dailyMinutes
        OnboardingPreferences.notificationsOptIn = notificationsOptIn
    }
}

/// Projection annuelle affichée après le choix du rythme quotidien.
/// Les constantes sont volontairement affichées à l'écran : rien n'est sorti d'un chapeau.
enum LearningProjection {
    /// Cartes parcourues en une minute de révision.
    static let cardsPerMinute = 4.0
    /// Passages nécessaires, en moyenne, pour ancrer durablement une carte.
    static let repetitionsPerCard = 8.0
    static let daysPerYear = 365.0

    static func cardsPerYear(dailyMinutes: Int) -> Int {
        let raw = Double(dailyMinutes) * daysPerYear * cardsPerMinute / repetitionsPerCard
        return Int((raw / 10).rounded()) * 10
    }
}
