import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre (V3.3, lot 10).
///
/// **Chaque écran fait une chose.** Mika parle à la première personne, chaque réponse reçoit
/// une réaction visible, un choix unique avance tout seul. Aucun écran n'en répète un autre.
///
/// Cinq actes :
///
/// 0. **Les stories** (`hookLogo`) : quatre pages qui montrent ce que fait l'app, dans un
///    aperçu du produit.
/// 1. **Faire connaissance** : Mika se présente, le prénom, le pays, la classe (filière et
///    année, ou palier large), ce qui arrive en premier (l'examen et sa date), les matières.
/// 2. **L'objectif** : l'objectif n°1, ce qui bloque, **ce que Mika y répond** (`solutionMap`),
///    les deux moyennes, la projection et l'engagement, le temps par jour, une vraie question
///    (et la seule étude citée du parcours), le rappel quotidien et son heure, **la première
///    leçon** (`firstLesson`).
/// 3. **Le plan** : Mika le prépare, puis le révèle. Le compte se propose en le quittant.
/// 4. **L'offre** : l'essai offert, le rappel promis (seulement s'il peut être tenu), le
///    paywall.
///
/// **Tout s'adapte au pays et à l'année** : filières, années, examens, matières, barème
/// (`SchoolSystem`, `SchoolExams`, `StudentGradeScale`), objectifs (`LearningGoal.offered`).
///
/// **Les noms sont ceux des statistiques** (`onboarding_step`) : les écrans gardés portent
/// le nom qu'ils avaient, deux sont nouveaux (`solutionMap`, `firstLesson`). Retirés par
/// rapport au lot 9,
/// et jamais remplacés à l'identique : `building`, `featuresIntro`, `mikaMission`,
/// `mikaSources`, `mikaPaths`, `mikaDesign`, `mikaTutor`, `mikaSolution`, `mikaRelief`,
/// `socialProof`, `studyTime` (fusionné dans `notifications`). Ce qu'ils disaient est dit une
/// fois : par les stories, et par `solutionMap`.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    // Acte 0 : les stories.
    /// Les quatre stories, sur un seul écran. Le nom reste celui du premier écran d'avant.
    case hookLogo

    // Acte 1 : faire connaissance.
    /// « Salut, moi c'est Mika ! » : un moment, avant la première question.
    case welcome
    /// « Comment je t'appelle ? » Obligatoire : tout ce qui suit s'adresse à quelqu'un.
    case name
    case country
    /// Le palier large, pour les pays dont on ne connaît pas les filières.
    case level
    /// La filière puis l'année, pour les pays décrits en détail.
    case schoolType
    case year
    /// **Ce qui arrive en premier** : l'examen du pays, un contrôle, ou rien ; et sa date.
    /// Il pré-remplit un examen dans le calendrier à la fin du parcours.
    case exam
    case subjects
    /// **Démo (lot 11) : ton cours devient une leçon**, dans la matière qu'il vient de cocher.
    case lessonDemo

    // Acte 2 : l'objectif.
    /// **L'objectif n°1**, parmi ceux de son niveau (`LearningGoal.offered(for:)`).
    case goal
    /// Ce qui le bloque. Plusieurs réponses ; l'écran suivant y répond.
    case worries
    /// **« Voilà comment je t'aide »** : pour chaque blocage coché (trois au plus), la
    /// fonctionnalité qui y répond.
    case solutionMap
    /// **Démo (lot 11) : le scanner d'exercices**, en réponse aux devoirs et aux cours durs.
    case scanDemo
    case currentAverage
    case targetAverage
    /// La projection (d'aujourd'hui à la date de l'examen) et l'engagement.
    case startingPoint
    case dailyTime
    /// **Démo (lot 11) : le plan dans le calendrier**, avec le temps qu'il vient de choisir,
    /// ses matières, son examen, et une séance de concentration.
    case planDemo
    /// **Une vraie question, sur sa matière**, et la seule étude citée du parcours
    /// (Karpicke & Roediger, 2008).
    case sampleCard
    /// **Démo (lot 11) : le chat avec Mika**, sur un sujet de sa matière et de son niveau.
    case chatDemo
    /// Le rappel quotidien : son heure (l'ancien écran `studyTime` est ici), puis la demande
    /// d'iOS.
    case notifications
    /// **« Par quel cours on commence ? »** : un sujet écrit, ou un cours à importer. La Home
    /// le lance à la sortie du parcours (`FirstLessonIntent`).
    case firstLesson

    // Acte 3 : le plan.
    /// Mika prépare le plan : le seul chargement du parcours.
    case planBuilding
    /// **Le plan révélé.** Le nom reste celui d'avant pour les statistiques.
    case profileSummary

    // Acte 4 : l'offre.
    /// « Je t'offre 3 jours pour essayer ton plan » : la durée vient du produit.
    case freeTrialIntro
    /// « Je te préviens avant la fin de ton essai » : promis seulement si le rappel peut
    /// être envoyé.
    case trialOffer
    /// **Pourquoi maintenant (lot 11)** : le compte à rebours de son examen, les séances qu'il
    /// reste si l'on commence ce soir, la première leçon prête. Le dernier écran avant l'offre.
    case whyNow
    case paywall

    var id: Int { rawValue }

    /// **Le compte se propose en quittant le plan révélé**, dans une languette : c'est là
    /// qu'il protège quelque chose, le plan qu'on vient de construire.
    static let accountStep: OnboardingStep = .profileSummary

    /// **Le nom de l'étape dans les statistiques.**
    ///
    /// Tiré du nom du cas plutôt que recopié dans une liste : une liste parallèle se
    /// désynchronise au premier écran ajouté. En échange, **renommer un cas coupe la courbe
    /// en deux** : c'est le prix, et il est assumé.
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
    /// On reprend là où l'élève s'est arrêté, sauf pour **l'accroche**, qui se refait : les
    /// stories, la présentation de Mika et le prénom.
    func resumePoint(hasName: Bool) -> OnboardingStep {
        switch self {
        case .hookLogo, .welcome, .name:
            .hookLogo
        case _ where !hasName:
            .hookLogo
        default:
            self
        }
    }

    /// **Les écrans que le pays fait sauter.**
    ///
    /// Chaque pays voit une seule des deux questions de niveau : les pays décrits en détail
    /// (`SchoolSystem`) ont une filière et une année, et le palier large s'en déduit. Les
    /// autres n'ont que le palier large : leur proposer une filière serait inventer des
    /// réponses fausses.
    func isSkipped(for country: SchoolingCountry, custom: WorldCountry? = nil) -> Bool {
        let detailed = SchoolSystem.isDetailed(country, custom: custom)
        switch self {
        case .schoolType, .year: return !detailed
        case .level: return detailed
        default: return false
        }
    }

    /// **L'écran qui suit un écran retiré**, pour reprendre un parcours commencé avant cette
    /// version : on continue sur le suivant qui existe encore, pas au début.
    static func replacement(forRetired name: String) -> OnboardingStep? {
        switch name {
        // Retirés au lot 10.
        case "studyTime": .notifications
        case "building", "featuresIntro", "mikaMission", "mikaSources", "mikaPaths": .sampleCard
        case "mikaDesign", "mikaTutor", "mikaSolution", "mikaRelief", "socialProof": .planBuilding
        // Retirés avant.
        case "proofRetention", "founders", "aiCompanion": .startingPoint
        case "supportUs": .planBuilding
        case "trialReminder": .trialOffer
        default: nil
        }
    }

    // MARK: - La forme de l'écran

    /// Les quatre formes d'un écran du parcours.
    enum Kind: Equatable {
        /// Les stories : plein écran, sans barre.
        case stories
        /// Un moment : un grand Mika centré, un titre, un bouton.
        case moment
        /// Une question : Mika et sa bulle en haut (`MikaAsk`), les réponses dessous.
        case question
        /// Une page à titre : une idée, une illustration, un bouton.
        case page
        /// Le paywall, qui porte sa propre croix.
        case paywall
    }

    var kind: Kind {
        switch self {
        case .hookLogo:
            .stories
        case .welcome, .planBuilding, .profileSummary, .freeTrialIntro:
            .moment
        case .name, .country, .level, .schoolType, .year, .exam, .subjects, .goal, .worries,
             .currentAverage, .targetAverage, .dailyTime, .sampleCard, .firstLesson:
            .question
        case .solutionMap, .startingPoint, .notifications, .trialOffer,
             .lessonDemo, .scanDemo, .planDemo, .chatDemo, .whyNow:
            .page
        case .paywall:
            .paywall
        }
    }

    /// Vrai pour les écrans où Mika pose une question dans sa bulle.
    var isQuestion: Bool { kind == .question }

    /// **Un choix unique avance tout seul à l'appui** : ces écrans n'ont pas de bouton.
    var advancesOnChoice: Bool {
        switch self {
        case .country, .level, .schoolType, .year, .goal, .dailyTime: true
        default: false
        }
    }

    /// **La barre du haut (le retour et la jauge) se montre sur les écrans du parcours, et se
    /// retire de ceux qui sont un moment à eux seuls** : les stories, le plan qui se prépare
    /// puis se révèle, et le paywall.
    var showsChrome: Bool {
        switch self {
        case .hookLogo, .planBuilding, .profileSummary, .paywall:
            false
        default:
            true
        }
    }

    /// **La jauge** accompagne les questions ; l'écran où Mika se présente n'a que le retour :
    /// rien n'a encore commencé.
    var showsProgress: Bool {
        self != .welcome
    }

    /// **Le chargement** : il ne se revisite pas, et avance seul. Le retour l'enjambe.
    var isLoading: Bool {
        self == .planBuilding
    }

    /// **Un écran d'où l'on peut revenir.** Tous, sauf le premier (rien derrière), le
    /// chargement, le plan révélé (un aboutissement) et le paywall, qui porte sa propre croix.
    /// Revenir jusqu'aux stories rend le choix de la langue.
    var allowsReturn: Bool {
        switch self {
        case .hookLogo, .profileSummary, .paywall: false
        default: !isLoading
        }
    }

    /// **L'écran dont la réponse est facultative** : la moyenne d'aujourd'hui, « Passer » en
    /// haut à droite. Passer saute aussi la moyenne visée.
    var isSkippable: Bool {
        self == .currentAverage
    }

    /// Position de l'étape dans la jauge, entre 0 et 1.
    ///
    /// La jauge couvre le parcours entier, des stories au paywall : elle avance toujours
    /// dans le même sens. Le plancher garde un filet visible dès le premier écran.
    var progress: Double {
        let last = Double(OnboardingStep.allCases.count - 1)
        guard last > 0 else { return 1 }
        return max(0.02, Double(rawValue) / last)
    }
}
