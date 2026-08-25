import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre. Le parcours est strictement
/// linéaire : aucun retour en arrière, on n'expose donc jamais d'étape précédente.
///
/// L'ordre raconte quelque chose : on accroche, on demande où étudie l'étudiant puis où il
/// en est, on explique la méthode, on la lui fait faire, puis on personnalise. La
/// démonstration suit exactement le parcours réel de l'app — on dépose un cours, il est mis
/// en fiche, il se décompose en cartes — parce qu'une démonstration qui montre autre chose
/// que le produit est une promesse qu'il faudra tenir deux fois.
///
/// **Le pays passe avant le niveau**, et ce n'est pas un détail d'ordre : ce sont les
/// paliers d'études du pays choisi qui deviennent les réponses de « tu en es où ? ». Poser
/// le niveau d'abord obligeait à proposer les mêmes sept réponses françaises à tout le
/// monde. La langue se déduit du même écran, et l'écran qui annonçait « Micabo parle
/// français » a disparu avec : il demandait une réponse qu'on ne pouvait pas donner.
///
/// **L'écran des rappels a disparu.** Il demandait « on te rappelle au bon moment ? » sans
/// rien demander au système : il notait une intention que rien ne lisait, et il la
/// demandait juste avant l'écran qui construit le parcours, c'est-à-dire au moment où l'on
/// est le plus près d'entrer dans l'app. Une autorisation de notification se demande quand
/// elle sert — la première fois qu'il y a des cartes à rappeler — et pas au milieu d'une
/// inscription.
///
/// La fin du parcours a sa propre progression, et elle est délibérée : le parcours vient
/// d'être construit sous les yeux (`personalizing`), d'autres l'ont déjà suivi
/// (`socialProof`), c'est maintenant à cet étudiant-là de s'y mettre (`yourTurn`), et on
/// ne lui demande de compte (`signIn`) qu'à cet instant. Demander de se connecter avant
/// d'avoir rien montré, c'est demander un compte pour une app qu'on n'a pas encore vue.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    case welcome
    case country
    case level
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
    /// ses fonds, elle vient de ce qu'il y a à regarder.
    ///
    /// **L'accroche n'est plus sur l'encre.** Ouvrir sur un écran entièrement noir donne le
    /// ton d'un outil de développeur, là où Micabo est une app d'école : on posait le
    /// contraste maximal de l'app avant d'avoir quoi que ce soit à lire, et tout ce qui
    /// suivait était forcément un repli. Elle est sur la sauge, un crème teinté de vert
    /// assez discret pour que l'écran suivant ne se lise pas comme une rupture.
    ///
    /// Reste un seul écran d'encre, et c'est le bon : le passage de relais, le seul moment
    /// où le parcours s'arrête de montrer pour s'adresser à quelqu'un. Le menthe, lui, sert
    /// l'attente — l'écran de génération était sur le vert plein, et un aplat saturé tenu
    /// cinq secondes derrière du texte blanc fatigue là où l'on demande de patienter.
    var surface: OnboardingSurface {
        switch self {
        case .welcome: .sage
        case .yourTurn: .ink
        case .personalizing: .accentSoft
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
