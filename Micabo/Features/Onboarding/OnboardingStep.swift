import Foundation

/// Les écrans du parcours d'accueil, dans l'ordre (version 2, novembre 2026).
///
/// **Mika pose les questions.** Chaque question est dite par Mika, en buste au bord de sa
/// ligne, dans une bulle qui s'écrit ; il réagit à certaines réponses (« Bac : encore
/// 7 mois. On a le temps de bien faire 💪 »). Le gabarit est le même pour toutes : Mika et sa
/// bulle en haut, les réponses dessous, le rond en bas à droite (`OnboardingScaffold`).
///
/// **Tout s'adapte au pays et à l'année** : les filières, les années, les examens (Bac,
/// Abitur, Matura, PAU, GCSE, SAT, ENEM, YKS…), les matières et leur nom local, le barème des
/// moyennes (`SchoolSystem`, `SchoolExams`, `StudentGradeScale`).
///
/// Cinq blocs :
///
/// 1. **L'accroche** : le logo, le prénom, la bienvenue.
/// 2. **Le profil scolaire** : pays, niveau (ou filière et année), le prochain examen et sa
///    date, les matières.
/// 3. **Les objectifs** : ce qui l'inquiète, pourquoi il apprend, les deux moyennes, le temps
///    par jour, l'heure de révision, les rappels.
/// 4. **Mika** : le profil se prépare, puis trois écrans de démonstration — les documents, les
///    parcours, le prof particulier. Le compte se propose en quittant le dernier.
/// 5. **Le plan et l'offre** : la preuve, Mika calcule, **la révélation du plan** (« Ton plan
///    pour le Bac est prêt »), la chronologie de l'essai, le paywall.
///
/// **Avant / après** : 36 écrans (35 vus en France), maintenant 25 (24 vus en France).
/// Retirés : `proofRetention` (devenu la réaction de Mika aux inquiétudes), `founders`,
/// `aiCompanion` (l'étude de Harvard est passée sur l'écran de preuve), `startingPoint` (Mika
/// pose déjà les questions), `featuresIntro`, `mikaMission`, `mikaDesign`, `mikaSolution`,
/// `mikaRelief`, `supportUs` (la note se demande après la première leçon terminée),
/// `freeTrialIntro` et `trialReminder` (regroupés dans la chronologie de l'essai). Ajouté :
/// `exam`. Les noms des écrans gardés ne changent pas : leurs courbes d'analytics continuent.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    // L'accroche.
    /// Le splash : le logo seul, puis la phrase et le bouton qui se posent dessous.
    case hookLogo
    /// « Comment veux-tu que je t'appelle ? » Obligatoire : tout ce qui suit s'adresse à
    /// quelqu'un.
    case name
    /// « Enchanté, {prénom} ! » Mika se présente, avant la première question.
    case welcome

    // Le profil scolaire.
    case country
    /// Le palier large, pour les pays dont on ne connaît pas les filières.
    case level
    /// La filière puis l'année, pour les pays décrits en détail.
    case schoolType
    case year
    /// **Le prochain examen**, dans les termes du pays, et sa date. Il pré-remplit un examen
    /// dans le calendrier à la fin du parcours.
    case exam
    case subjects

    // Les objectifs.
    /// Ce qui l'inquiète dans ses études. Plusieurs réponses ; Mika y répond.
    case worries
    case goal
    case currentAverage
    case targetAverage
    /// « Combien de temps par jour ? », sur un curseur qui dessine la progression estimée.
    case dailyTime
    /// L'heure à laquelle il révise : c'est celle du rappel.
    case studyTime
    case notifications

    // Mika prépare, puis se présente.
    /// Le chargement : Mika se présente pendant que le profil se construit.
    case building
    /// Il prend tous tes documents : cours, PDF, notes, YouTube.
    case mikaSources
    /// … et il en fait des parcours simples, faits pour toi.
    case mikaPaths
    /// « Mika, c'est ton prof particulier, disponible à tout moment, dans ta poche. »
    case mikaTutor

    // Le plan, puis l'offre.
    /// La preuve, sourcée : l'étude de Harvard et ce qu'il reste d'un cours relu ou testé.
    case socialProof
    /// Mika calcule le plan : le chargement d'avant la révélation.
    case planBuilding
    /// **La révélation du plan** (« Ton plan pour le Bac est prêt ») : pays, classe, examen,
    /// matières, temps par jour, moyenne visée. Le nom de l'écran reste celui d'avant pour les
    /// statistiques.
    case profileSummary
    /// La chronologie de l'essai : aujourd'hui, le rappel, le premier prélèvement, et
    /// « annule quand tu veux ».
    case trialOffer
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
    func isSkipped(for country: SchoolingCountry, custom: WorldCountry? = nil) -> Bool {
        let detailed = SchoolSystem.isDetailed(country, custom: custom)
        switch self {
        case .schoolType, .year: return !detailed
        case .level: return detailed
        default: return false
        }
    }

    /// **L'écran qui remplace un écran retiré**, pour reprendre un parcours commencé avant la
    /// version 2 : on reprend au même moment du parcours, pas au logo.
    static func replacement(forRetired name: String) -> OnboardingStep? {
        switch name {
        case "proofRetention", "founders", "aiCompanion", "startingPoint": .currentAverage
        case "featuresIntro", "mikaMission": .mikaSources
        case "mikaDesign", "mikaSolution", "mikaRelief": .mikaTutor
        case "supportUs": .planBuilding
        case "freeTrialIntro", "trialReminder": .trialOffer
        default: nil
        }
    }

    /// **L'icône 3D en tête de la question**, comme l'illustration des écrans de Mika : elle
    /// dit le sujet de la page avant qu'on lise le titre.
    var heroIcon: MicaboIcon? {
        switch self {
        case .country: .globe
        case .level, .schoolType: .diploma
        case .year: .book
        case .exam: .exam
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
        case .name, .country, .level, .schoolType, .year, .exam, .subjects, .worries, .goal,
             .currentAverage, .targetAverage, .dailyTime, .studyTime:
            true
        default:
            false
        }
    }

    /// **L'humeur de Mika quand il pose la question** : il salue au prénom, regarde autour de
    /// lui pour le pays, réfléchit sur l'année, s'étonne de l'examen, écrit les matières, fait
    /// un clin d'œil aux objectifs. Une réponse le fait sourire (`OnboardingMikaPrompt`).
    var mikaMood: MikaMood {
        switch self {
        case .name: .wave
        case .country, .studyTime: .look
        case .level, .schoolType, .year, .currentAverage: .think
        case .exam: .surprise
        case .subjects: .write
        case .goal, .notifications: .wink
        case .targetAverage: .happy
        default: .idle
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
