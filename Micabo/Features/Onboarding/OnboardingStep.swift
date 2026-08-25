import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre. Le parcours est strictement
/// linéaire : aucun retour en arrière, on n'expose donc jamais d'étape précédente.
///
/// L'ordre raconte quelque chose : on accroche, on demande où en est l'étudiant, on
/// explique la méthode, on la lui fait faire, puis on personnalise. La démonstration suit
/// exactement le parcours réel de l'app — on dépose un cours, il est mis en fiche, il se
/// décompose en cartes — parce qu'une démonstration qui montre autre chose que le produit
/// est une promesse qu'il faudra tenir deux fois.
///
/// La fin du parcours a sa propre progression, et elle est délibérée : le parcours vient
/// d'être construit sous les yeux (`personalizing`), d'autres l'ont déjà suivi
/// (`socialProof`), c'est maintenant à cet étudiant-là de s'y mettre (`yourTurn`), et on
/// ne lui demande de compte (`signIn`) qu'à cet instant. Demander de se connecter avant
/// d'avoir rien montré, c'est demander un compte pour une app qu'on n'a pas encore vue.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    case welcome
    case level
    case language
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
    case socialProof
    case yourTurn
    case signIn
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
    /// Trois écrans seulement quittent le crème : la variété d'un parcours ne vient pas de
    /// ses fonds, elle vient de ce qu'il y a à regarder. L'encre sert les deux moments où
    /// le parcours s'adresse directement à l'étudiant — l'accroche et le passage à son
    /// tour — et l'indigo sert l'attente.
    var surface: OnboardingSurface {
        switch self {
        case .welcome, .yourTurn: .ink
        case .personalizing: .indigo
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
