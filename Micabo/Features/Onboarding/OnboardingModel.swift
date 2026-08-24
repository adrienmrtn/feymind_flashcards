import Observation
import SwiftUI

/// État partagé du parcours d'accueil. Les réponses sont écrites au fil de l'eau
/// dans `OnboardingPreferences` : quitter l'app en cours de route ne les perd pas.
@Observable
final class OnboardingModel {
    private(set) var step: OnboardingStep = .welcome

    var level: StudyLevel?
    var goals: Set<LearningGoal> = []
    var forgetsOften: Bool?
    var subjects: Set<String> = []
    var institutionId: String?
    var institutionName: String?
    var dailyMinutes = 15
    var notificationsOptIn = false

    /// Nombre de cartes que l'utilisateur peut espérer mémoriser en un an,
    /// au rythme qu'il vient de choisir.
    var projectedCardsPerYear: Int {
        LearningProjection.cardsPerYear(dailyMinutes: dailyMinutes)
    }

    /// Plafond de cartes neuves par jour qui découle du rythme choisi.
    var newCardsPerDay: Int {
        DailyLoad.newCardsPerDay(dailyMinutes: dailyMinutes)
    }

    /// Vrai seulement si l'établissement a été choisi dans la liste de résultats.
    /// Un nom tapé à la main n'a pas d'`id` : on ne connaît alors personne là-bas,
    /// et on ne prétend pas le contraire.
    var hasRecognizedInstitution: Bool {
        institutionId?.nilIfBlank != nil
    }

    /// Le parcours est une file droite : chaque écran a quelque chose à demander ou à
    /// montrer, donc aucun ne se saute. Le mécanisme d'écran conditionnel qui existait ici
    /// ne servait qu'à la preuve sociale, qui a été retirée.
    func advance() {
        persist()
        guard let next = step.next else { return }
        step = next
    }

    /// Recopie les réponses dans les réglages à chaque changement d'écran :
    /// une sortie en cours de route ne perd que la question en cours.
    private func persist() {
        OnboardingPreferences.level = level?.rawValue
        OnboardingPreferences.goals = goals.map(\.rawValue).sorted()
        OnboardingPreferences.forgetsOften = forgetsOften
        OnboardingPreferences.subjects = subjects.sorted()
        OnboardingPreferences.institutionId = institutionId
        OnboardingPreferences.institutionName = institutionName
        OnboardingPreferences.dailyMinutes = dailyMinutes
        OnboardingPreferences.notificationsOptIn = notificationsOptIn
    }
}

