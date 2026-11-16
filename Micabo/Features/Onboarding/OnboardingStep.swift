import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre (lot 14 : le parcours en chapitres).
///
/// **Sept chapitres courts, chacun ouvert par Mika** (`Kind.chapter`) : un grand Mika, le nom
/// du chapitre, une phrase forte. La jauge du haut a un segment par chapitre.
///
/// 0. **Les stories** (`hookLogo`), hors chapitre.
/// 1. **Faisons connaissance** : Mika se présente, puis le prénom, le pays, la classe,
///    l'examen, les matières.
/// 2. **Ce qui coince** : la matière la plus dure, l'objectif, les blocages, le temps, la
///    méthode, puis « Je t'ai compris » (`solutionMap`).
/// 3. **Comment Mika t'aide** : d'où vient Mika, tes cours deviennent des leçons, le scanner
///    (avec une matière scientifique), et ce que dit la recherche.
/// 4. **Ton objectif** : les deux moyennes, la courbe, le temps par jour.
/// 5. **Ton organisation** : la semaine au calendrier, la concentration, le rappel,
///    l'engagement.
/// 6. **Ton plan** : le plan qui se construit, le plan prêt.
/// 7. **Ta première leçon** : une leçon racontée du début à la fin (la Révolution française),
///    puis « Et toi, ta première leçon ? », l'essai et le paywall (lot 15).
///
/// **Les noms sont ceux des statistiques** (`onboarding_step`) : les écrans gardés portent le
/// nom qu'ils avaient ; le lot 14 en ajoute treize et en retire trois (`cardsDemo`,
/// `examDemo`, `sampleCard`), repris par `replacement(forRetired:)`.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    /// Les quatre stories, sur un seul écran.
    case hookLogo

    // Chapitre 1 : faisons connaissance.
    /// « Salut, moi c'est Mika ! » : l'ouverture du premier chapitre.
    case welcome
    /// « Comment je t'appelle ? » Obligatoire : tout ce qui suit s'adresse à quelqu'un.
    case name
    /// **« Et toi, tu es… ? »** : un homme, une femme, autre. Facultative (« Passer »).
    case gender
    case country
    /// Le palier large, pour les pays dont on ne connaît pas les filières.
    case level
    /// La filière puis l'année, pour les pays décrits en détail.
    case schoolType
    case year
    /// **Ce qui arrive en premier** : l'examen du pays, un contrôle, ou rien ; et sa date.
    case exam
    case subjects

    // Chapitre 2 : ce qui coince.
    /// **« Parle-moi de tes cours »** : l'ouverture du chapitre.
    case studyIntro
    /// **La matière la plus dure**, parmi celles cochées. Sautée quand il n'y en a qu'une.
    case hardestSubject
    /// **L'objectif n°1**, parmi ceux de son niveau (`LearningGoal.offered(for:)`).
    case goal
    /// Ce qui le bloque. Plusieurs réponses.
    case worries
    /// **Le temps de révision par semaine, aujourd'hui.**
    case studyHours
    /// **Comment il révise aujourd'hui.**
    case studyMethod
    /// **« Je t'ai compris »** : Mika reformule les réponses.
    case solutionMap

    // Chapitre 3 : comment je t'aide.
    /// **« Voyons comment je peux t'aider, et jusqu'où on peut aller ensemble »**.
    case helpIntro
    /// **D'où vient Mika** : créé par des élèves qui voulaient ranger leur pile de cours.
    case origin
    /// **Tes cours deviennent des leçons**, quelle que soit leur source.
    case lessonDemo
    /// **Démo : le scanner d'exercices**, étape par étape, sur un exercice de maths de sa
    /// classe. Sautée sans matière scientifique (lot 15).
    case scanDemo
    /// **Ce que dit la recherche** : Kestin et al., Scientific Reports, 2025.
    case research

    // Chapitre 4 : ton objectif.
    /// **« Fixons ton objectif »**.
    case goalIntro
    case currentAverage
    case targetAverage
    /// La projection, d'aujourd'hui à la date de l'examen : la courbe se trace.
    case startingPoint
    /// Le temps par jour, au curseur : de 5 minutes à 2 heures.
    case dailyTime

    // Chapitre 5 : ton organisation.
    /// **« Je ne suis pas que ton prof »** : organiser, se concentrer.
    case organizeIntro
    /// **Démo : sa semaine dans le calendrier**, un jour à toucher.
    case planDemo
    /// **Démo : une séance de concentration**, à lancer.
    case focusDemo
    /// Le rappel quotidien : son heure, puis la demande d'iOS.
    case notifications
    /// **L'engagement** : un vrai maintien sur le sceau.
    case commitment

    // Chapitre 6 : ton plan.
    /// Mika prépare le plan : le seul chargement du parcours. Il ouvre le chapitre.
    case planBuilding
    /// **Le plan prêt**, comme un objet.
    case profileSummary

    // Chapitre 7 : ta première leçon.
    /// **« Voyons une leçon, du début à la fin »** : l'exemple annoncé (lot 15).
    case storyIntro
    /// **Imagine : la Révolution française.** Les supports, la question, « Créer la leçon ».
    case storyCreate
    /// **Le parcours qui en sort**, fondé sur la recherche en sciences cognitives.
    case storyPath
    /// **Quiz et cartes** : tu connais ta leçon.
    case storyPractice
    /// **Une question en plus**, de quoi impressionner tes profs.
    case storyAsk
    /// **« Mika a été créé pour te faire aimer apprendre »** : la conclusion du récit.
    case storyClose
    /// **« Et toi, ta première leçon, ce sera quoi ? »** (lot 15 : après l'exemple). Rien ne
    /// s'écrit ici : la Home la proposera.
    case firstLesson
    /// **« On veut que tu essaies Micabo Pro gratuitement »**. Sauté sans essai offert.
    case freeTrialIntro
    /// **« On t'enverra un rappel avant la fin de ton essai »**. Sauté sans essai.
    case trialOffer
    case paywall

    var id: Int { rawValue }

    /// **Le compte se propose en quittant le plan révélé**, dans une languette.
    static let accountStep: OnboardingStep = .profileSummary

    /// **Le nom de l'étape dans les statistiques**, tiré du nom du cas : renommer un cas coupe
    /// sa courbe en deux.
    var analyticsName: String {
        String(describing: self)
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    /// **Où reprendre un parcours laissé sur cet écran** : là où l'élève s'est arrêté, sauf
    /// pour l'accroche, qui se refait (les stories, la présentation de Mika et le prénom).
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

    /// **Les écrans que le pays fait sauter** : une seule des deux questions de niveau.
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
        case "building", "featuresIntro", "mikaMission", "mikaSources", "mikaPaths": .currentAverage
        case "mikaDesign", "mikaTutor", "mikaSolution", "mikaRelief", "socialProof": .planBuilding
        // Retirés avant.
        case "proofRetention", "founders", "aiCompanion": .startingPoint
        case "supportUs": .planBuilding
        case "trialReminder": .trialOffer
        // Retirés au lot 13.
        case "lessonBuilding", "lessonReady": .freeTrialIntro
        case "whyNow": .paywall
        // Retirés au lot 14 : la carte isolée (les cartes reviennent dans la démo finale), le
        // jour J, la question d'essai.
        case "cardsDemo": .scanDemo
        case "examDemo": .research
        case "sampleCard": .currentAverage
        // Retiré au lot 15 : le chat, redit par la question à Mika du récit final.
        case "chatDemo": .research
        // Retiré au lot 16 (« enlève la page Mika n'est pas un simple ChatGPT »).
        case "notJustChat": .research
        default: nil
        }
    }

    // MARK: - Les chapitres

    /// **Les sept chapitres de la jauge.** Les stories et le paywall n'en font pas partie.
    static let chapterCount = 7

    /// Le chapitre de l'écran, de 0 à `chapterCount - 1`.
    var chapter: Int {
        switch self {
        case .hookLogo, .welcome, .name, .gender, .country, .level, .schoolType, .year, .exam, .subjects:
            0
        case .studyIntro, .hardestSubject, .goal, .worries, .studyHours, .studyMethod, .solutionMap:
            1
        case .helpIntro, .origin, .lessonDemo, .scanDemo, .research:
            2
        case .goalIntro, .currentAverage, .targetAverage, .startingPoint, .dailyTime:
            3
        case .organizeIntro, .planDemo, .focusDemo, .notifications, .commitment:
            4
        case .planBuilding, .profileSummary:
            5
        case .storyIntro, .storyCreate, .storyPath, .storyPractice, .storyAsk, .storyClose,
             .firstLesson, .freeTrialIntro, .trialOffer, .paywall:
            6
        }
    }

    /// La clé du nom d'un chapitre (« Comment je t'aide »).
    static func chapterTitleKey(_ chapter: Int) -> String {
        "ios.onb14.chapter.\(chapter + 1)"
    }

    /// Les écrans d'un chapitre, dans l'ordre.
    static func steps(inChapter chapter: Int) -> [OnboardingStep] {
        allCases.filter { $0.chapter == chapter && $0 != .hookLogo && $0 != .paywall }
    }

    /// **L'avancée dans le chapitre**, de 0 à 1 (exclus) : l'écran qui ouvre le chapitre montre
    /// déjà un filet.
    var chapterFraction: Double {
        let steps = Self.steps(inChapter: chapter)
        guard let index = steps.firstIndex(of: self) else { return 0 }
        return Double(index + 1) / Double(steps.count + 1)
    }

    /// **L'écran qui ouvre un chapitre** : celui où Mika parle seul, en grand.
    var opensChapter: Bool {
        kind == .chapter || self == .planBuilding
    }

    // MARK: - La forme de l'écran

    enum Kind: Equatable {
        /// Les stories : plein écran, sans barre.
        case stories
        /// **L'ouverture d'un chapitre** : le nom du chapitre, un grand Mika, une phrase.
        case chapter
        /// Un moment : un grand Mika, un titre, un bouton.
        case moment
        /// Une question : le titre en grand, Mika qui réagit dessous, les réponses.
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
        case .welcome, .studyIntro, .helpIntro, .goalIntro, .organizeIntro, .storyIntro:
            .chapter
        case .solutionMap, .planBuilding, .profileSummary, .storyClose:
            .moment
        case .name, .gender, .country, .level, .schoolType, .year, .exam, .subjects, .hardestSubject,
             .goal, .worries, .studyHours, .studyMethod, .currentAverage, .targetAverage,
             .dailyTime, .firstLesson:
            .question
        case .origin, .lessonDemo, .scanDemo, .planDemo, .focusDemo:
            .demo
        case .research, .startingPoint, .notifications, .commitment, .storyCreate,
             .storyPath, .storyPractice, .storyAsk, .freeTrialIntro, .trialOffer:
            .page
        case .paywall:
            .paywall
        }
    }

    var isQuestion: Bool { kind == .question }

    /// **Les questions à choix unique** : une réponse se coche, et « Continuer » avance
    /// (`OnbPickButton`).
    var isSingleChoice: Bool {
        switch self {
        case .gender, .country, .level, .schoolType, .year, .hardestSubject, .goal, .studyHours, .studyMethod:
            true
        default:
            false
        }
    }

    /// **Aucun écran n'avance plus à l'appui d'une réponse** (demande du fondateur : « qu'on
    /// ne passe pas direct au clic ») : chaque question a son bouton.
    var advancesOnChoice: Bool { false }

    /// **La barre du haut** se retire des écrans qui sont un moment à eux seuls.
    var showsChrome: Bool {
        switch self {
        case .hookLogo, .planBuilding, .profileSummary, .paywall:
            false
        default:
            true
        }
    }

    /// **La jauge** accompagne tout le parcours, dès Mika.
    var showsProgress: Bool {
        showsChrome
    }

    /// **Le chargement** : il ne se revisite pas, et avance seul. Le retour l'enjambe.
    var isLoading: Bool {
        self == .planBuilding
    }

    /// **Un écran d'où l'on peut revenir** : tous, sauf le premier, le chargement, le plan
    /// révélé et le paywall.
    var allowsReturn: Bool {
        switch self {
        case .hookLogo, .profileSummary, .paywall: false
        default: !isLoading
        }
    }

    /// **Les écrans dont la réponse est facultative** (« Passer », en haut à droite) : le
    /// genre, et la moyenne d'aujourd'hui.
    var isSkippable: Bool {
        self == .gender || self == .currentAverage
    }

    /// Position de l'étape dans le parcours entier, entre 0 et 1.
    var progress: Double {
        let last = Double(OnboardingStep.allCases.count - 1)
        guard last > 0 else { return 1 }
        return max(0.02, Double(rawValue) / last)
    }
}
