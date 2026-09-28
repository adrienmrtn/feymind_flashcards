import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre.
///
/// **Le parcours est un quiz, et le quiz est le produit.** Les apps qui convertissent
/// (Cal AI, Coconote, Quizlet) posent vingt questions avant de montrer un prix, et chaque
/// question a la même forme : un titre en gras, trois à cinq cartes grises, un bouton
/// noir. Entre les questions, des écrans de preuve : un chiffre en couleur dans une phrase
/// noire, un graphe à deux courbes, une carte d'avis. L'élève lit parce qu'on parle de lui,
/// et il arrive au compte, puis à l'offre, avec un plan qui porte ses chiffres.
///
/// Quatre blocs :
///
/// 1. **L'accroche** : le logo, la note, puis deux écrans qui parlent de lui avant la
///    première question — relire ne suffit pas, et c'est pour ça que Micabo existe.
/// 2. **Le quiz**, avec les preuves intercalées : pays, niveau, matières, d'où il vient,
///    son objectif, ses deux moyennes, son temps, sa signature, sa méthode, son prénom.
/// 3. **La construction** : merci, les avis, le plan se calcule, le plan est prêt.
/// 4. **Le compte et les rappels** : le compte, l'heure où il révise, la notification ;
///    puis l'essai et le paywall.
///
/// **Le pays passe avant le niveau**, et le niveau avant les matières : chacun décide des
/// réponses du suivant. La langue se déduit du pays, et ne se demande pas.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    // L'accroche.
    /// Le splash : le logo seul, puis la phrase et le bouton qui se posent dessous.
    case hookLogo
    case hookRating
    /// Relire, c'est oublier : deux barres.
    case proofRetention
    /// « C'est pour ça qu'on a créé Micabo » : une phrase qui se lit, et rien d'autre.
    case proofWhy

    // Le quiz.
    case country
    /// Le palier large, pour les pays dont on ne connaît pas les filières.
    case level
    /// La filière puis l'année, pour les pays décrits en détail.
    case schoolType
    case year
    case subjects
    case source
    case goal
    case currentAverage
    case targetAverage
    case proofRealistic
    case dailyTime
    /// La signature : « tu as choisi dix minutes par jour, signe ici ».
    case commitment
    case proofCurve
    case method
    case name

    // La construction.
    case thanks
    /// Les avis, en carrousel : la preuve sociale, au moment où l'on rend.
    case reviews
    case building
    case planReady

    // Le compte et les rappels.
    case signIn
    /// L'heure à laquelle il révise : c'est celle du rappel.
    case studyTime
    case notifications

    // L'essai, puis l'offre.
    case trialOffer
    case trialReminder
    case paywall

    var id: Int { rawValue }

    /// **Le nom de l'étape dans les statistiques.**
    ///
    /// Tiré du nom du cas plutôt que recopié dans une liste : une liste parallèle se
    /// désynchronise au premier écran ajouté, et un entonnoir dont un cran porte le nom
    /// d'un autre écran est pire qu'un entonnoir incomplet. En échange, **renommer un cas
    /// coupe la courbe en deux** — c'est le prix, et il est assumé.
    var analyticsName: String {
        String(describing: self)
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    /// **Chaque pays voit une seule des deux questions de niveau.**
    ///
    /// Les pays décrits en détail (`SchoolSystem`) ont une filière et une année, et le
    /// palier large s'en déduit. Les autres n'ont que le palier large : leur proposer une
    /// filière serait inventer des réponses fausses, et un élève à qui l'on propose une
    /// année qui n'existe pas chez lui comprend tout de suite que l'app n'a pas été écrite
    /// pour lui.
    func isSkipped(for country: SchoolingCountry) -> Bool {
        switch self {
        case .schoolType, .year: !SchoolSystem.isDetailed(country)
        case .level: SchoolSystem.isDetailed(country)
        default: false
        }
    }

    /// Vrai pour les écrans qui posent une question. Ce sont les seuls où l'on revient.
    var isQuestion: Bool {
        switch self {
        case .country, .level, .schoolType, .year, .subjects, .source, .goal,
             .currentAverage, .targetAverage, .dailyTime, .method, .name:
            true
        default:
            false
        }
    }

    /// Fond de l'étape, et seule source de vérité à ce sujet.
    ///
    /// **Tout est blanc.** La variété d'un parcours ne vient pas de ses fonds, elle vient
    /// de ce qu'il y a à regarder ; et un parcours qui change de couleur à chaque écran se
    /// lit comme un carrousel.
    var surface: OnboardingSurface {
        .canvas
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
