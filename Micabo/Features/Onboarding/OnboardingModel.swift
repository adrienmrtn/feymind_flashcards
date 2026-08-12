import Observation
import SwiftUI

/// État partagé du parcours d'accueil. Les réponses sont écrites au fil de l'eau
/// dans `OnboardingPreferences` : quitter l'app en cours de route ne les perd pas.
@Observable
final class OnboardingModel {
    private(set) var step: OnboardingStep = .welcome

    var goal: LearningGoal? {
        didSet { OnboardingPreferences.goal = goal }
    }

    var forgetsOften: Bool? {
        didSet { OnboardingPreferences.forgetsOften = forgetsOften }
    }

    var subjects: Set<String> = [] {
        didSet { OnboardingPreferences.subjects = subjects.sorted() }
    }

    var dailyMinutes: Int = 15 {
        didSet { OnboardingPreferences.dailyMinutes = dailyMinutes }
    }

    var notificationsOptIn: Bool = false {
        didSet { OnboardingPreferences.notificationsOptIn = notificationsOptIn }
    }

    /// Nombre de cartes que l'utilisateur peut espérer mémoriser en un an,
    /// au rythme qu'il vient de choisir.
    var projectedCardsPerYear: Int {
        LearningProjection.cardsPerYear(dailyMinutes: dailyMinutes)
    }

    func advance() {
        guard let next = step.next else { return }
        step = next
    }

    func jump(to step: OnboardingStep) {
        self.step = step
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
