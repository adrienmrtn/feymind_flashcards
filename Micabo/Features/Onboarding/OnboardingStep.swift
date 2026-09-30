import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre.
///
/// **Le parcours est un quiz, puis une démonstration, puis une offre.** Il pose ses
/// questions d'abord — le prénom, le pays, les matières, ce qui inquiète, les deux moyennes,
/// le temps par jour, l'heure du rappel — parce qu'un élève lit un parcours qui parle de lui.
/// Il rend ensuite : Mika prépare le profil, cinq écrans disent ce que l'app fait, puis
/// l'élève **voit un cours fiché** — le sien, importé pour de vrai, ou un cours de
/// démonstration — et s'entraîne sur trois cartes. La preuve sociale et l'offre ne
/// viennent qu'après ça, quand il y a quelque chose à prouver.
///
/// Six blocs :
///
/// 1. **L'accroche** : le logo, le prénom, la bienvenue.
/// 2. **Le quiz** : pays, niveau, matières, inquiétudes, objectifs, une preuve, les deux
///    moyennes, le temps par jour, l'heure de révision, les rappels.
/// 3. **Mika** : le profil se prépare, puis ce que Micabo sait faire, en cinq écrans.
/// 4. **Le cours** : le compte (une languette, qu'on peut passer), les cases de dépôt — ou, à qui n'a rien, un cours de
///    démonstration —, la construction, le cours fiché qu'on parcourt.
/// 5. **Les cartes** : trois cartes, puis « bien joué ».
/// 6. **L'offre** : la preuve sociale, l'essai, le rappel, le paywall.
///
/// **Le pays passe avant le niveau**, et le niveau avant les matières : chacun décide des
/// réponses du suivant. La langue se déduit du pays, et ne se demande pas.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    // L'accroche.
    /// Le splash : le logo seul, puis la phrase et le bouton qui se posent dessous.
    case hookLogo
    /// « Comment veux-tu qu'on t'appelle ? » Obligatoire : tout ce qui suit s'adresse à
    /// quelqu'un.
    case name
    /// « Bienvenue, {prénom}. » Une page pour une phrase, avant la première question.
    case welcome

    // Le quiz.
    case country
    /// Le palier large, pour les pays dont on ne connaît pas les filières.
    case level
    /// La filière puis l'année, pour les pays décrits en détail.
    case schoolType
    case year
    case subjects
    /// Ce qui l'inquiète dans ses études. Plusieurs réponses.
    case worries
    case goal
    /// « On s'en occupe » : deux barres, relire contre se tester.
    case proofRetention
    case currentAverage
    case targetAverage
    /// Le temps par jour, sur un curseur qui dessine la progression estimée.
    case dailyTime
    /// L'heure à laquelle il révise : c'est celle du rappel.
    case studyTime
    case notifications

    // Mika prépare, puis montre.
    /// Le chargement : Mika se présente pendant que le profil se construit.
    case building
    /// « Voyons maintenant comment Micabo peut t'aider. »
    case featuresIntro
    case featureSheets
    case featurePlan
    case featureCards
    case featurePocket
    case featureMika
    /// « Voyons ensemble à quoi ressemble une fiche générée par Micabo. »
    case sheetIntro

    // Le cours. Le compte se propose juste avant, dans une languette qui monte sur
    // `sheetIntro` (`OnboardingAccountSheet`) : ce n'est plus une page du parcours.
    /// Les cases de dépôt, et « je n'ai rien pour l'instant » à côté du rond : c'est la
    /// seule branche du parcours, et elle se prend sur l'écran même, sans question avant.
    case materials
    /// Un cours de démonstration à choisir, pour qui n'a rien déposé.
    case demoCourse
    /// La construction du cours, réelle ou jouée.
    case courseBuilding
    /// Le cours fiché, qu'on parcourt librement.
    case courseReview

    // Les cartes.
    /// « Envie de t'entraîner sur quelques cartes ? »
    case trainPrompt
    /// Trois cartes : une recto verso, un QCM, un texte à trou.
    case trainCards
    case wellDone

    // La preuve, puis l'offre.
    /// « On a aidé 45 000 élèves », avec les avis — et la demande de note du système.
    case socialProof
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

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    /// **Les écrans que le parcours saute, selon ce qui a été répondu.**
    ///
    /// Chaque pays voit une seule des deux questions de niveau : les pays décrits en détail
    /// (`SchoolSystem`) ont une filière et une année, et le palier large s'en déduit. Les
    /// autres n'ont que le palier large : leur proposer une filière serait inventer des
    /// réponses fausses.
    ///
    /// Les cases de dépôt se montrent toujours ; le cours de démonstration ne se choisit que
    /// si l'on a dit, sur les cases, n'avoir rien pour l'instant. On ne choisit pas un cours
    /// joué quand on vient de déposer le sien.
    ///
    /// Quand la construction du cours a échoué et qu'on continue sans, le cours, les cartes
    /// et le bravo se sautent aussi : il n'y a rien à parcourir ni à réviser.
    func isSkipped(for country: SchoolingCountry, hasMaterials: Bool? = nil, courseUnavailable: Bool = false) -> Bool {
        switch self {
        case .schoolType, .year: !SchoolSystem.isDetailed(country)
        case .level: SchoolSystem.isDetailed(country)
        case .demoCourse: hasMaterials != false
        case .courseReview, .trainPrompt, .trainCards, .wellDone: courseUnavailable
        default: false
        }
    }

    /// Vrai pour les écrans qui posent une question.
    var isQuestion: Bool {
        switch self {
        case .name, .country, .level, .schoolType, .year, .subjects, .worries, .goal,
             .currentAverage, .targetAverage, .dailyTime, .studyTime, .materials, .demoCourse:
            true
        default:
            false
        }
    }

    /// **La barre du haut — la pilule de retour et la jauge — se montre sur les écrans qui
    /// font partie du parcours, et se retire de ceux qui sont un moment à eux seuls** : le
    /// splash, les deux chargements, le cours qu'on parcourt, les cartes, le bravo, et le
    /// paywall qui porte sa propre croix.
    var showsChrome: Bool {
        switch self {
        case .hookLogo, .building, .courseBuilding, .courseReview, .trainCards, .wellDone, .paywall:
            false
        default:
            true
        }
    }

    /// **Le premier écran où l'on peut revenir, et le dernier.**
    ///
    /// On revient jusqu'au pays, et pas plus loin : le prénom et la bienvenue ne se défont
    /// pas. On ne revient plus après les rappels : tout ce qui suit est un résultat, une
    /// démonstration, un compte ou une offre, et rien de tout ça ne se défait.
    static let firstReturnable: OnboardingStep = .country
    static let lastReturnable: OnboardingStep = .notifications

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
    /// La jauge couvre le parcours entier, du premier écran au paywall : elle avance
    /// toujours dans le même sens. Le plancher garde un filet visible dès le premier écran,
    /// pour qu'elle ne ressemble jamais à une barre cassée.
    var progress: Double {
        let last = Double(OnboardingStep.allCases.count - 1)
        guard last > 0 else { return 1 }
        return max(0.02, Double(rawValue) / last)
    }
}
