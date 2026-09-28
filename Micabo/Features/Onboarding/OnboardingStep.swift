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
/// 1. **L'accroche** : le produit en mouvement, la note, où on l'a vu.
/// 2. **Le quiz**, avec les preuves intercalées : pays, niveau, matières, d'où il vient,
///    ce qu'il a essayé, son objectif, ses deux moyennes, son temps, ce qui le bloque, sa
///    prochaine échéance, sa méthode, son prénom.
/// 3. **La construction** : merci, le plan se calcule, le plan est prêt.
/// 4. **Le compte et les rappels**, puis l'essai et le paywall, inchangés.
///
/// **Le pays passe avant le niveau**, et le niveau avant les matières : chacun décide des
/// réponses du suivant. La langue se déduit du pays, et ne se demande pas.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    // L'accroche.
    case hookVideo
    case hookRating

    // Le quiz.
    case country
    /// Le palier large, pour les pays dont on ne connaît pas les filières.
    case level
    /// La filière puis l'année, pour les pays décrits en détail.
    case schoolType
    case year
    case subjects
    case source
    case triedApps
    case goal
    case currentAverage
    case targetAverage
    case proofRealistic
    case dailyTime
    case proofRetention
    case blocker
    case nextExam
    case proofCurve
    case method
    case proofStudents
    case name
    case proofPlan

    // La construction.
    case thanks
    case building
    case planReady

    // Le compte et les rappels.
    case signIn
    case notifications

    // L'essai, puis l'offre. Inchangés.
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
        case .country, .level, .schoolType, .year, .subjects, .source, .triedApps, .goal,
             .currentAverage, .targetAverage, .dailyTime, .blocker, .nextExam, .method, .name:
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
