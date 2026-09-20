import Observation
import SwiftUI

/// État partagé du parcours d'accueil. Les réponses sont écrites au fil de l'eau
/// dans `OnboardingPreferences` : quitter l'app en cours de route ne les perd pas.
@Observable
final class OnboardingModel {
    private(set) var step: OnboardingStep = .howItWorks

    /// **Le prénom, et rien d'autre.** Il ne sert qu'à s'adresser à quelqu'un — l'écran
    /// suivant dit « enchanté », et le parcours cesse de parler à un utilisateur. C'est une
    /// raison suffisante, et c'est la seule : rien d'autre ne le lit.
    var displayName: String = ""

    /// Le palier d'études, dans les termes du pays choisi. Il n'est proposé qu'après le
    /// pays, faute de quoi il n'y aurait rien de juste à proposer.
    ///
    /// Le `didSet` marque la réponse plutôt que l'écran : « a vu l'écran du palier » et
    /// « a choisi un palier » sont deux chiffres différents, et c'est leur écart qui dit
    /// qu'une liste de choix ne parle pas.
    var stage: EducationStage? {
        didSet {
            guard let stage, stage != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "stage", "value": .text(stage.id)])
        }
    }
    private(set) var country: SchoolingCountry = .guessed()
    /// Le pays nommé à la main, quand la réponse est « Autre pays ». Il n'a de sens que dans
    /// ce cas-là, et il est effacé dès qu'on revient sur une pastille.
    var customCountry: WorldCountry?
    var goals: Set<LearningGoal> = []
    var subjects: Set<String> = []

    /// **La filière suivie**, dans les termes du pays. Elle ne se demande qu'aux pays
    /// décrits en détail ; ailleurs, le palier large (`stage`) est tout ce qu'on sait.
    var track: SchoolTrack? {
        didSet {
            guard let track, track != oldValue else { return }
            // Changer de filière efface l'année : « Terminale » accrochée à « Collège » est
            // une réponse que personne n'a donnée.
            if oldValue != nil { year = nil }
            // Le palier large suit la filière : c'est lui que la fonction Edge reçoit et que
            // le cloud synchronise, et il ne doit pas rester sur la réponse d'avant.
            stage = country.resolvedStage(id: nil, tier: track.tier, level: track.level)
            Analytics.track(.onboardingAnswer, ["field": "track", "value": .text(track.id)])
        }
    }

    /// L'année dans la filière. Elle décide des matières proposées deux écrans plus loin.
    var year: SchoolYear? {
        didSet {
            guard let year, year != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "year", "value": .text(year.id)])
        }
    }
    /// La moyenne d'aujourd'hui, sur l'échelle 10-20. `TargetScore.min - 1` veut dire « en
    /// dessous du barème » : c'est le seul cran hors échelle, et il existe parce qu'un
    /// parcours qui ne propose que la moyenne et au-dessus dit à celui qui rame qu'il n'est
    /// pas prévu.
    var currentScore: Int? {
        didSet {
            guard let currentScore, currentScore != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "currentScore", "value": .number(Double(currentScore))])
        }
    }
    /// La moyenne visée. Toujours au-dessus de l'actuelle.
    var targetScore: Int? {
        didSet {
            guard let targetScore, targetScore != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "targetScore", "value": .number(Double(targetScore))])
        }
    }
    /// Le registre de rédaction, seule forme sous laquelle le niveau sort du parcours.
    var level: StudyLevel? {
        stage?.level
    }

    /// La langue de rédaction : celle du pays, et elle ne se demande pas séparément.
    var language: ContentLanguage {
        country.language
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
        // La filière et l'année appartiennent à un système scolaire : « Fen Lisesi » n'existe
        // pas en France, et la garder afficherait une réponse introuvable dans la liste. Le
        // palier, lui, se reporte — c'est tout l'objet de `resolvedStage`.
        track = nil
        year = nil
        // Repartir sur une pastille efface le pays tapé à la main : le garder ferait dire à
        // l'écran « France » et « Brésil » en même temps.
        if newCountry != .other { customCountry = nil }
        Analytics.track(.onboardingAnswer, ["field": "country", "value": .text(newCountry.rawValue)])
    }

    /// Vrai quand la question du pays a une réponse complète. « Autre pays » n'en est une
    /// qu'une fois le pays choisi dans la liste : sans ça, on avance sur un « ailleurs » qui
    /// ne dit rien de plus que le silence.
    var hasAnsweredCountry: Bool {
        country != .other || customCountry != nil
    }

    /// **Le rythme quotidien ne se demande plus ici.** L'écran qui le posait, et celui qui
    /// en tirait une projection sur un an, ont été retirés : personne ne connaît son rythme
    /// avant d'avoir essayé, et la promesse chiffrée reposait sur une réponse au hasard. Le
    /// plafond garde sa valeur par défaut et se règle dans les Réglages.

    /// Les filières proposées, vides quand le pays n'est pas décrit en détail.
    var tracks: [SchoolTrack] {
        SchoolSystem.tracks(for: country)
    }

    /// Le parcours est une file droite : chaque écran a quelque chose à demander ou à
    /// montrer, donc aucun ne se saute.
    func advance() {
        persist()
        var next = step.next
        // Les écrans sans réponse possible se sautent plutôt que de s'afficher vides : un
        // pays dont on ne connaît que les paliers larges n'a ni filière ni année à proposer.
        while let candidate = next, candidate.isSkipped(for: country) {
            next = candidate.next
        }
        guard let next else { return }
        step = next
    }

    /// Recopie les réponses dans les réglages à chaque changement d'écran :
    /// une sortie en cours de route ne perd que la question en cours.
    private func persist() {
        OnboardingPreferences.schoolingCountry = country
        OnboardingPreferences.customCountry = customCountry
        OnboardingPreferences.educationStage = stage
        OnboardingPreferences.goals = goals.map(\.rawValue).sorted()
        OnboardingPreferences.subjects = subjects.sorted()
        OnboardingPreferences.currentScore = currentScore
        OnboardingPreferences.targetScore = targetScore
        OnboardingPreferences.displayName = displayName.nilIfBlank
        OnboardingPreferences.schoolTrackID = track?.id
        OnboardingPreferences.schoolYearID = year?.id
    }
}

