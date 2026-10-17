import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre.
///
/// **Le parcours est un quiz, puis Mika, puis une offre.** Il pose ses questions d'abord — le
/// prénom, le pays, les matières, ce qui inquiète, les deux moyennes, le temps par jour,
/// l'heure du rappel — parce qu'un élève lit un parcours qui parle de lui. Mika prépare
/// ensuite le profil, puis six écrans disent ce qu'il fait : sa mission, les documents qu'il
/// prend, les parcours qu'il en tire, des leçons qui donnent envie, la solution, la fin de la
/// pression. La preuve sociale et l'offre viennent après.
///
/// **Le parcours n'écrit plus de cours.** La première leçon se crée dans l'app, depuis Home :
/// c'est là qu'elle a ses vraies portes (sujet tapé, PDF, photos, YouTube), et le parcours
/// n'en joue plus une version réduite.
///
/// Quatre blocs :
///
/// 1. **L'accroche** : le logo, le prénom, la bienvenue.
/// 2. **Le quiz** : pays, niveau, matières, inquiétudes, objectifs, une preuve, les deux
///    moyennes, le temps par jour, l'heure de révision, les rappels.
/// 3. **Mika** : le profil se prépare, « voyons comment Mika peut t'aider », puis six écrans.
///    Le compte se propose en quittant le dernier, dans une languette.
/// 4. **L'offre** : la preuve sociale, l'essai, le rappel, le paywall.
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
    /// « Micabo a été créé par deux étudiants… » : l'histoire, avant les chiffres.
    case founders
    /// « L'IA est le compagnon le plus incroyable pour apprendre » : l'étude de Harvard.
    case aiCompanion
    /// « Maintenant, partons de là où tu en es » : le pont vers les deux moyennes.
    case startingPoint
    case currentAverage
    case targetAverage
    /// « Combien de temps es-tu prêt à étudier sur Micabo par jour ? », sur un curseur qui
    /// dessine la progression estimée.
    case dailyTime
    /// L'heure à laquelle il révise : c'est celle du rappel.
    case studyTime
    case notifications

    // Mika prépare, puis se présente.
    /// Le chargement : Mika se présente pendant que le profil se construit.
    case building
    /// « Voyons maintenant comment Mika peut t'aider. »
    case featuresIntro
    /// Sa mission : les cours les plus interactifs possibles, pour apprendre simplement.
    case mikaMission
    /// Il prend tous tes documents : cours, PDF, notes, YouTube.
    case mikaSources
    /// … et il en fait des parcours simples, faits pour toi.
    case mikaPaths
    /// Des leçons qui donnent vraiment envie d'étudier.
    case mikaDesign
    /// « Mika, c'est ton prof particulier, disponible à tout moment, dans ta poche. »
    case mikaTutor
    /// La solution pour travailler efficacement et facilement.
    case mikaSolution
    /// La pression et la montagne de choses à revoir, c'est fini.
    case mikaRelief

    // La preuve, puis l'offre.
    /// « On a aidé 45 000 élèves », l'étude de Harvard, les avis — et la demande de note du
    /// système.
    case socialProof
    /// « Soutiens-nous » : le bouton suivant ouvre la demande de note du système, puis avance.
    case supportUs
    /// Mika calcule le parcours : le chargement d'après la preuve.
    case planBuilding
    /// « Voici ton profil » : les réponses relues, et ce que Mika va en faire.
    case profileSummary
    /// « Nous tenons à ce que tu essaies gratuitement » : Mika couronné, avant l'essai.
    case freeTrialIntro
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

    /// **Où reprendre un parcours laissé sur cet écran.**
    ///
    /// Un élève qui sort de l'app pendant le parcours revient souvent sur une app qu'iOS a
    /// fermée entre-temps. Il repartait du logo, trente écrans plus tôt, et une fois sur deux
    /// il ne refaisait pas le chemin. On reprend donc là où il s'est arrêté, sauf pour
    /// **l'accroche**, qui se refait : trois écrans, et le prénom en fait partie.
    func resumePoint(hasName: Bool) -> OnboardingStep {
        switch self {
        case .hookLogo, .name, .welcome:
            .hookLogo
        case _ where !hasName:
            .hookLogo
        default:
            self
        }
    }

    /// **Les écrans que le parcours saute, selon ce qui a été répondu.**
    ///
    /// Chaque pays voit une seule des deux questions de niveau : les pays décrits en détail
    /// (`SchoolSystem`) ont une filière et une année, et le palier large s'en déduit. Les
    /// autres n'ont que le palier large : leur proposer une filière serait inventer des
    /// réponses fausses.
    func isSkipped(for country: SchoolingCountry) -> Bool {
        switch self {
        case .schoolType, .year: !SchoolSystem.isDetailed(country)
        case .level: SchoolSystem.isDetailed(country)
        default: false
        }
    }

    /// **L'icône 3D en tête de la question**, comme l'illustration des écrans de Mika : elle
    /// dit le sujet de la page avant qu'on lise le titre.
    var heroIcon: MicaboIcon? {
        switch self {
        case .country: .globe
        case .level, .schoolType: .diploma
        case .year: .book
        case .subjects: .lightbulb
        case .worries: .brain
        case .goal: .rocket
        case .currentAverage: .exam
        case .targetAverage: .trophy
        case .dailyTime: .hourglass
        case .studyTime: .alarm
        case .notifications: .check
        default: nil
        }
    }

    /// Vrai pour les écrans qui posent une question.
    var isQuestion: Bool {
        switch self {
        case .name, .country, .level, .schoolType, .year, .subjects, .worries, .goal,
             .currentAverage, .targetAverage, .dailyTime, .studyTime:
            true
        default:
            false
        }
    }

    /// **La barre du haut — la pilule de retour et la jauge — se montre sur les écrans qui
    /// font partie du parcours, et se retire de ceux qui sont un moment à eux seuls** : le
    /// splash, le chargement du profil, et le paywall qui porte sa propre croix.
    var showsChrome: Bool {
        switch self {
        case .hookLogo, .building, .paywall:
            false
        default:
            true
        }
    }

    /// **Les chargements** : ils ne se revisitent pas, et ne portent pas de flèche — ils
    /// avancent seuls. Le retour les enjambe.
    var isLoading: Bool {
        switch self {
        case .building, .planBuilding: true
        default: false
        }
    }

    /// **Un écran d'où l'on peut revenir.** Tous, sauf le premier (rien derrière), les
    /// chargements, et le paywall, qui porte sa propre croix. Revenir jusqu'à l'accroche
    /// rend le choix de la langue à qui ne l'avait pas vu, ou dont le téléphone l'avait
    /// mal deviné.
    var allowsReturn: Bool {
        switch self {
        case .hookLogo, .paywall: false
        default: !isLoading
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
    /// La jauge couvre le parcours entier, du premier écran au paywall : elle avance
    /// toujours dans le même sens. Le plancher garde un filet visible dès le premier écran,
    /// pour qu'elle ne ressemble jamais à une barre cassée.
    var progress: Double {
        let last = Double(OnboardingStep.allCases.count - 1)
        guard last > 0 else { return 1 }
        return max(0.02, Double(rawValue) / last)
    }
}
