import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre (lot 12 : l'entonnoir reconstruit).
///
/// **Un fil psychologique en huit actes**, une action par écran, un temps fort toutes les
/// quatre à six étapes :
///
/// 0. **L'accroche** (`hookLogo`) : les stories du produit.
/// 1. **Toi** : Mika se présente et pose le cadre, puis le prénom, le pays, la classe,
///    l'examen et sa date, les matières. Chaque réponse revient à l'écran suivant.
/// 2. **Ce qui bloque** : la matière la plus dure, l'objectif n°1, les blocages, le temps de
///    révision, la méthode d'aujourd'hui, puis **Mika reformule** (`solutionMap`).
/// 3. **Les réponses, à jouer** : une démonstration jouable par blocage (la leçon, les
///    cartes, le scanner, le chat, l'examen blanc), sur sa matière.
/// 4. **La preuve par l'essai** : une vraie question (`sampleCard`), de l'XP réellement gagnée.
/// 5. **La projection et l'engagement** : les deux moyennes, la courbe, le temps par jour, la
///    semaine au calendrier, une séance de concentration, le rappel, **l'engagement**.
/// 6. **Le plan** : la première leçon, le plan qui se construit en citant les réponses, puis
///    le plan prêt, comme un objet à lui.
/// 7. **Vers l'offre** : ce que l'essai débloque, comment il se passe (dates réelles, rappel),
///    pourquoi maintenant, puis le paywall (et, refermé, l'offre de réduction).
///
/// **Les noms sont ceux des statistiques** (`onboarding_step`) : les écrans gardés portent le
/// nom qu'ils avaient ; le lot 12 en ajoute sept (`hardestSubject`, `studyHours`,
/// `studyMethod`, `cardsDemo`, `examDemo`, `focusDemo`, `commitment`), sans en renommer.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    // Acte 0 : les stories.
    /// Les quatre stories, sur un seul écran. Le nom reste celui du premier écran d'avant.
    case hookLogo

    // Acte 1 : toi.
    /// « Salut, moi c'est Mika ! » et le cadre : quelques questions, et ton plan.
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

    // Acte 2 : ce qui bloque.
    /// **La matière la plus dure**, parmi celles cochées : c'est elle que les démonstrations
    /// et la question d'essai prennent. Sautée quand il n'y en a qu'une.
    case hardestSubject
    /// **L'objectif n°1**, parmi ceux de son niveau (`LearningGoal.offered(for:)`).
    case goal
    /// Ce qui le bloque. Plusieurs réponses.
    case worries
    /// **Le temps de révision par semaine, aujourd'hui** : ce que ça lui coûte.
    case studyHours
    /// **Comment il révise aujourd'hui.**
    case studyMethod
    /// **« Je t'ai compris »** : Mika reformule les réponses (sa matière, ses blocages, son
    /// temps, sa méthode), puis annonce les démonstrations. Le nom reste celui d'avant.
    case solutionMap

    // Acte 3 : les réponses, à jouer.
    /// **Démo : ton cours devient une leçon**, dans sa matière la plus dure.
    case lessonDemo
    /// **Démo : une carte à retourner**, et la répétition au bon moment.
    case cardsDemo
    /// **Démo : le scanner d'exercices**, étape par étape.
    case scanDemo
    /// **Démo : le chat avec Mika**, une question à choisir.
    case chatDemo
    /// **Démo : un examen blanc corrigé.**
    case examDemo

    // Acte 4 : la preuve par l'essai.
    /// **Une vraie question, sur sa matière**, l'XP gagnée, et la seule étude citée du
    /// parcours (Karpicke & Roediger, 2008).
    case sampleCard

    // Acte 5 : la projection et l'engagement.
    case currentAverage
    case targetAverage
    /// La projection, d'aujourd'hui à la date de l'examen : la courbe se trace.
    case startingPoint
    case dailyTime
    /// **Démo : sa semaine dans le calendrier**, un jour à toucher.
    case planDemo
    /// **Démo : une séance de concentration**, à lancer.
    case focusDemo
    /// Le rappel quotidien : son heure (l'ancien écran `studyTime` est ici), puis la demande
    /// d'iOS.
    case notifications
    /// **L'engagement** : un appui long sur « Je m'engage », qui scelle ce qu'il a dit.
    case commitment

    // Acte 6 : le plan.
    /// Mika prépare le plan : le seul chargement du parcours.
    case planBuilding
    /// **Le plan prêt**, comme un objet. Le nom reste celui d'avant pour les statistiques.
    case profileSummary
    /// **« Par quel cours on commence ce soir ? »** : un sujet écrit, ou un cours à importer —
    /// l'élève investit dans le plan qu'il vient de recevoir. La Home le lance à la sortie du
    /// parcours (`FirstLessonIntent`).
    case firstLesson

    // Acte 7 : vers l'offre.
    /// Ce que l'essai débloque. La durée vient du produit.
    case freeTrialIntro
    /// Comment l'essai se passe : la chronologie datée, et le rappel qu'on active soi-même.
    case trialOffer
    /// **Pourquoi maintenant** : son examen, sa leçon prête, sa séance de ce soir.
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

    // MARK: - Les actes

    /// **Les sept actes de la jauge**, des questions au paywall (les stories n'en font pas
    /// partie : la jauge commence avec Mika).
    static let actCount = 7

    /// L'acte de l'écran, de 0 à `actCount - 1` (les stories et le paywall sont hors jauge).
    var act: Int {
        switch self {
        case .hookLogo, .welcome, .name, .country, .level, .schoolType, .year, .exam, .subjects:
            0
        case .hardestSubject, .goal, .worries, .studyHours, .studyMethod, .solutionMap:
            1
        case .lessonDemo, .cardsDemo, .scanDemo, .chatDemo, .examDemo:
            2
        case .sampleCard:
            3
        case .currentAverage, .targetAverage, .startingPoint, .dailyTime, .planDemo, .focusDemo,
             .notifications, .commitment:
            4
        case .planBuilding, .profileSummary, .firstLesson:
            5
        case .freeTrialIntro, .trialOffer, .whyNow, .paywall:
            6
        }
    }

    /// Les écrans d'un acte, dans l'ordre.
    static func steps(inAct act: Int) -> [OnboardingStep] {
        allCases.filter { $0.act == act && $0 != .hookLogo }
    }

    /// **L'avancée dans l'acte**, de 0 (premier écran de l'acte) à 1 (le dernier fini). Le
    /// premier écran d'un acte montre déjà un filet : on y est entré.
    var actFraction: Double {
        let steps = Self.steps(inAct: act)
        guard let index = steps.firstIndex(of: self) else { return 0 }
        return Double(index + 1) / Double(steps.count + 1)
    }

    // MARK: - La forme de l'écran

    /// Les formes d'un écran du parcours.
    enum Kind: Equatable {
        /// Les stories : plein écran, sans barre.
        case stories
        /// Un moment : un grand Mika, un titre, un bouton.
        case moment
        /// Une question : le titre en grand, Mika qui réagit dessous, les réponses groupées.
        case question
        /// Une démonstration jouable : un morceau d'app, et le bouton qui le joue.
        case demo
        /// Une page à titre : une idée, une illustration, un bouton.
        case page
        /// Le paywall, qui porte sa propre croix.
        case paywall
    }

    var kind: Kind {
        switch self {
        case .hookLogo:
            .stories
        case .welcome, .solutionMap, .planBuilding, .profileSummary:
            .moment
        case .name, .country, .level, .schoolType, .year, .exam, .subjects, .hardestSubject,
             .goal, .worries, .studyHours, .studyMethod, .currentAverage, .targetAverage,
             .dailyTime, .sampleCard, .firstLesson:
            .question
        case .lessonDemo, .cardsDemo, .scanDemo, .chatDemo, .examDemo, .planDemo, .focusDemo:
            .demo
        case .startingPoint, .notifications, .commitment, .freeTrialIntro, .trialOffer, .whyNow:
            .page
        case .paywall:
            .paywall
        }
    }

    /// Vrai pour les écrans qui posent une question.
    var isQuestion: Bool { kind == .question }

    /// **Un choix unique avance tout seul** : la ligne se coche, son ressort se joue, et la
    /// page part à la fin du ressort. Leur bouton « Continuer » reste au pied, comme partout,
    /// pour qui revient sur l'écran.
    var advancesOnChoice: Bool {
        switch self {
        case .country, .level, .schoolType, .year, .hardestSubject, .goal, .studyHours,
             .studyMethod, .dailyTime:
            true
        default:
            false
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

    /// **La jauge** accompagne tout le parcours, dès que Mika a parlé.
    var showsProgress: Bool {
        self != .welcome
    }

    /// **Le chargement** : il ne se revisite pas, et avance seul. Le retour l'enjambe.
    var isLoading: Bool {
        self == .planBuilding
    }

    /// **Un écran d'où l'on peut revenir.** Tous, sauf le premier (rien derrière), le
    /// chargement, le plan révélé (un aboutissement) et le paywall, qui porte sa propre croix.
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

    /// Position de l'étape dans le parcours entier, entre 0 et 1 : elle avance toujours dans
    /// le même sens.
    var progress: Double {
        let last = Double(OnboardingStep.allCases.count - 1)
        guard last > 0 else { return 1 }
        return max(0.02, Double(rawValue) / last)
    }
}
