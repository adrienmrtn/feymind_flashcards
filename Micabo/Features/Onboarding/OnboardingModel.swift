import Observation
import SwiftUI

/// État partagé du parcours d'accueil. Les réponses sont écrites au fil de l'eau
/// dans `OnboardingPreferences` : quitter l'app en cours de route ne les perd pas.
@Observable
final class OnboardingModel {
    private(set) var step: OnboardingStep = .welcome

    /// Le palier d'études, dans les termes du pays choisi. Il n'est proposé qu'après le
    /// pays, faute de quoi il n'y aurait rien de juste à proposer.
    var stage: EducationStage?
    private(set) var country: SchoolingCountry = .fallback
    var goals: Set<LearningGoal> = []
    var forgetting: ForgettingHabit?
    var subjects: Set<String> = []
    var institutionId: String?
    var institutionName: String?
    var dailyMinutes = 15

    /// Le registre de rédaction, seule forme sous laquelle le niveau sort du parcours.
    var level: StudyLevel? {
        stage?.level
    }

    /// La langue de rédaction : celle du pays, et elle ne se demande pas séparément.
    var language: ContentLanguage {
        country.language
    }

    /// Le rapport à l'oubli ramené à un oui ou un non, pour le réglage historique.
    var forgetsOften: Bool? {
        forgetting?.forgetsOften
    }

    /// Changer de pays change les réponses de la question suivante.
    ///
    /// Le palier déjà choisi est reporté sur son équivalent dans le nouveau pays — sa marche
    /// exacte, sinon la plus proche en montant — et abandonné quand il n'a pas d'équivalent :
    /// garder « PASS » après un passage aux États-Unis laisserait affichée une réponse qui
    /// n'existe pas dans la liste.
    func select(country newCountry: SchoolingCountry) {
        guard newCountry != country else { return }
        let previous = stage
        country = newCountry
        stage = newCountry.resolvedStage(id: nil, tier: previous?.tier, level: previous?.level)
    }

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
    /// montrer, donc aucun ne se saute.
    func advance() {
        persist()
        guard let next = step.next else { return }
        step = next
    }

    /// Recopie les réponses dans les réglages à chaque changement d'écran :
    /// une sortie en cours de route ne perd que la question en cours.
    private func persist() {
        OnboardingPreferences.schoolingCountry = country
        OnboardingPreferences.educationStage = stage
        OnboardingPreferences.goals = goals.map(\.rawValue).sorted()
        OnboardingPreferences.forgetting = forgetting
        OnboardingPreferences.forgetsOften = forgetsOften
        OnboardingPreferences.subjects = subjects.sorted()
        OnboardingPreferences.institutionId = institutionId
        OnboardingPreferences.institutionName = institutionName
        OnboardingPreferences.dailyMinutes = dailyMinutes
    }
}

