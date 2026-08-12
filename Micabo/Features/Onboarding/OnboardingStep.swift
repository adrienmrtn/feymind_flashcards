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
    case video
    case generatedCards
    case subjects
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

    /// Les écrans d'accroche et la fin du parcours se passent de jauge.
    var showsProgress: Bool {
        switch self {
        case .welcome, .personalizing, .trialOffer, .trialReminder, .paywall: false
        default: true
        }
    }

    /// Position de l'étape dans la jauge, entre 0 et 1.
    var progress: Double {
        let tracked = OnboardingStep.allCases.filter(\.showsProgress)
        guard let index = tracked.firstIndex(of: self), tracked.count > 1 else { return 0 }
        return Double(index) / Double(tracked.count - 1)
    }
}
