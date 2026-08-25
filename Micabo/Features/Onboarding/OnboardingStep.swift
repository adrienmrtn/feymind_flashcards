import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre. Le parcours est strictement
/// linéaire : aucun retour en arrière, on n'expose donc jamais d'étape précédente.
///
/// L'ordre raconte quelque chose : on accroche, on demande où en est l'étudiant, on
/// explique la méthode, on la lui fait faire, puis on personnalise. La démonstration suit
/// exactement le parcours réel de l'app — on dépose un cours, il est mis en fiche, il se
/// décompose en cartes — parce qu'une démonstration qui montre autre chose que le produit
/// est une promesse qu'il faudra tenir deux fois.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    case welcome
    case level
    case language
    case country
    case personalizeIntro
    case goal
    case forgetting
    case retentionChart
    case demoImport
    case demoSheet
    case demoReview
    case examPromise
    case subjects
    case school
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

    /// Fond de l'étape, et seule source de vérité à ce sujet : l'écran s'y peint, mais
    /// aussi le bandeau qui porte la jauge et la zone d'état au-dessus. Une bande claire
    /// posée au-dessus d'un écran sombre se lit comme un bug d'affichage.
    ///
    /// Deux écrans seulement quittent le crème, et c'est un de moins qu'avant : la variété
    /// d'un parcours ne vient pas de ses fonds, elle vient de ce qu'il y a à regarder. Le
    /// noir sert l'accroche, le vert sert l'attente.
    var surface: OnboardingSurface {
        switch self {
        case .welcome: .ink
        case .personalizing: .accent
        default: .canvas
        }
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
