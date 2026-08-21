import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre. Le parcours est strictement
/// linéaire : aucun retour en arrière, on n'expose donc jamais d'étape précédente.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    case welcome
    case language
    case personalizeIntro
    case goal
    case forgetting
    case retentionChart
    case science
    case demoImport
    case demoWrite
    case demoReview
    case subjects
    case school
    case schoolPeers
    case dailyTime
    case projection
    case notifications
    case personalizing
    case trialOffer
    case trialReminder
    case paywall

    var id: Int { rawValue }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    /// Position de l'étape dans la jauge, entre 0 et 1.
    ///
    /// La jauge couvre le parcours entier, du premier écran au paywall : elle ne
    /// disparaît sur aucune étape, et elle avance toujours dans le même sens. Le
    /// plancher garde un filet visible dès le premier écran, pour qu'elle ne
    /// ressemble jamais à une barre cassée.
    var progress: Double {
        let last = Double(OnboardingStep.allCases.count - 1)
        guard last > 0 else { return 1 }
        return max(0.02, Double(rawValue) / last)
    }
}
