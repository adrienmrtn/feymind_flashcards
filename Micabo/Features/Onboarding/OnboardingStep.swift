import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre.
///
/// **Le parcours a changé d'ordre, et c'est la mesure qui l'a décidé.** Les écrans d'intro
/// de la version précédente se traversaient en une à deux secondes chacun — quatre-vingt
/// pour cent des élèves passaient « Fonctions » en moins de deux secondes — tandis que les
/// questions étaient lues : neuf secondes sur l'objectif, vingt-six sur les matières. Ce qui
/// est montré avant qu'on sache à qui on parle n'est pas regardé ; ce qui est montré dans
/// la matière qu'on vient de choisir l'est.
///
/// D'où les trois blocs :
///
/// 1. **Qui tu es**, d'abord : le pays, l'objectif, la filière, l'année, les matières, le
///    prénom. Ce sont les écrans que l'élève lit, et leurs réponses colorent tout le reste.
/// 2. **La démonstration, dans ta matière** : une vraie fiche de la matière choisie avec
///    son graphe, une carte qu'on retourne soi-même, le plan jusqu'à la vraie date de
///    l'examen du pays, un examen blanc corrigé, un chiffre, trois avis. Chaque écran montre
///    un résultat, pas une promesse, et son bouton ne s'ouvre qu'une fois le résultat vu.
/// 3. **Où tu en es, puis le compte et l'offre** : les moyennes, les rappels, la
///    construction du parcours, ce qu'il contient, la connexion, la preuve sociale chiffrée,
///    le passage de relais, l'essai, ce que Pro débloque, le paywall.
///
/// Ce qui a disparu : la mascotte qui se présentait, la grille des formats de dépôt, la
/// liste des fonctions, l'écran « enchanté ». Quatre écrans que personne ne lisait, remplacés
/// par six que l'on regarde parce qu'ils parlent de soi.
///
/// **Le pays passe avant la filière**, et la filière avant l'année : chacune décide des
/// réponses de la suivante. La langue se déduit du pays, et ne se demande pas.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    // Qui tu es.
    case howItWorks
    case country
    case goal
    case schoolType
    case year
    case subjects
    case name

    // La démonstration, dans ta matière.
    case demoSheet
    case demoCard
    case demoPlan
    case demoMock
    case demoEvidence
    case demoReviews

    // Où tu en es.
    case currentAverage
    case targetAverage
    case together

    // Ce qui t'aidera à t'y tenir.
    case notifications

    // La construction, le compte, puis l'offre.
    case personalizing
    case pathReady
    case signIn
    case socialProof
    case yourTurn
    case trialOffer
    case trialReminder
    case proUnlocks
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

    /// **L'écran de la filière et celui de l'année se sautent** dans les pays dont on ne
    /// connaît que les paliers larges.
    ///
    /// Inventer des filières pour un pays qu'on ne décrit pas produirait des réponses
    /// fausses, et un élève à qui l'on propose une année qui n'existe pas chez lui comprend
    /// tout de suite que l'app n'a pas été écrite pour lui. Le palier large reste alors la
    /// seule chose qu'on demande, et il suffit à la génération.
    func isSkipped(for country: SchoolingCountry) -> Bool {
        switch self {
        case .schoolType, .year: !SchoolSystem.isDetailed(country)
        default: false
        }
    }

    /// **Les écrans qu'on regarde avant de pouvoir continuer.**
    ///
    /// Sur ces six écrans, le bouton se remplit pendant deux secondes et demie avant
    /// d'accepter l'appui. C'est la seule façon de garantir qu'une fiche ou un examen
    /// blanc a été vu : la mesure disait qu'un écran de démonstration se passait en une
    /// seconde, soit moins que le temps de le lire. Les questions, elles, ne sont jamais
    /// retenues — un élève qui sait répondre doit pouvoir aller vite.
    var isGated: Bool {
        switch self {
        case .howItWorks, .demoSheet, .demoPlan, .demoMock, .demoEvidence, .demoReviews: true
        default: false
        }
    }

    /// Fond de l'étape, et seule source de vérité à ce sujet : l'écran s'y peint, mais
    /// aussi le bandeau qui porte la jauge et la zone d'état au-dessus. Une bande claire
    /// posée au-dessus d'un écran sombre se lit comme un bug d'affichage.
    ///
    /// Un seul écran quitte le blanc : le passage de relais. La variété d'un parcours ne
    /// vient pas de ses fonds, elle vient de ce qu'il y a à regarder.
    var surface: OnboardingSurface {
        switch self {
        case .yourTurn: .ink
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
