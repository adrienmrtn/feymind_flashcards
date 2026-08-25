import Foundation

/// Objectif déclaré à l'inscription. Sert plus tard à ajuster les rappels et les suggestions.
///
/// Un libellé, et rien d'autre. Le sous-titre et l'icône qui accompagnaient chaque objectif
/// ont disparu avec les rangées qui les affichaient : sept lignes à picto et sous-titre font
/// lire des pictogrammes au lieu des réponses.
enum LearningGoal: String, CaseIterable, Identifiable {
    case language
    case exam
    case competition
    case lectures
    case profession
    case curiosity
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .language: "Apprendre une langue"
        case .exam: "Réviser pour un examen"
        case .competition: "Préparer un concours"
        case .lectures: "Retenir mes cours"
        case .profession: "Monter en compétences pour le travail"
        case .curiosity: "Nourrir ma culture générale"
        case .other: "Autre chose"
        }
    }

    /// Un emoji par réponse. Il ne remplace pas le libellé, il l'accroche : on retrouve sa
    /// réponse d'un regard au lieu de relire sept lignes qui commencent toutes par un verbe.
    var emoji: String {
        switch self {
        case .language: "🗣️"
        case .exam: "📝"
        case .competition: "🏁"
        case .lectures: "📚"
        case .profession: "💼"
        case .curiosity: "🧠"
        case .other: "✨"
        }
    }
}

/// Où en est l'étudiant dans ses études.
///
/// Une seule réponse, et sept possibilités : c'est la question qui situe tout le reste, et
/// elle est posée juste après l'accroche parce qu'un lycéen et un PASS n'ont ni les mêmes
/// matières, ni les mêmes examens, ni le même rythme.
enum StudyLevel: String, CaseIterable, Identifiable {
    case lycee
    case prepa
    case licence
    case sante
    case master
    case concours
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lycee: "Lycée"
        case .prepa: "Prépa"
        case .licence: "Licence"
        case .sante: "PASS, santé"
        case .master: "Master"
        case .concours: "Concours"
        case .other: "Autre"
        }
    }

    var emoji: String {
        switch self {
        case .lycee: "🎒"
        case .prepa: "📐"
        case .licence: "🎓"
        case .sante: "🩺"
        case .master: "🔬"
        case .concours: "🏁"
        case .other: "✨"
        }
    }

    /// Ce à quoi le stade engage la fiche, dit en une ligne dans les réglages.
    ///
    /// Le même chapitre ne s'écrit pas pareil pour un terminale et pour un PASS : ce n'est
    /// pas une question de longueur, c'est le niveau d'exigence du vocabulaire et la nature
    /// de ce qui est attendu à l'épreuve. La phrase le dit, parce qu'un réglage dont on ne
    /// voit pas l'effet ne se touche pas.
    var detail: String {
        switch self {
        case .lycee: "Vocabulaire du programme, attendus du bac."
        case .prepa: "Raisonnements complets, exigence de concours."
        case .licence: "Termes du cours magistral, cadrage disciplinaire."
        case .sante: "Densité et précision d'un tutorat santé."
        case .master: "Débats du champ, nuances et limites."
        case .concours: "Ce qui tombe, et les pièges classiques."
        case .other: "Rédaction équilibrée, sans niveau supposé."
        }
    }
}

/// Où l'étudiant est scolarisé.
///
/// La question est posée juste après la langue, et pour la même raison : parler français ne
/// dit pas dans quel système on étudie. « Les attendus du bac » ne veut rien dire pour un
/// lycéen belge, un étudiant québécois ne passe pas de concours de première année de santé,
/// et « baccalauréat » désigne au Québec un diplôme universitaire. Une fiche qui renvoie à un
/// examen qui n'existe pas là où on étudie perd sa raison d'être.
///
/// Dix pays, et pas une liste mondiale : ce sont ceux où l'on étudie en français. Le drapeau
/// tient lieu d'icône, parce qu'il se reconnaît plus vite que son nom.
enum SchoolingCountry: String, CaseIterable, Identifiable {
    case fr
    case be
    case ch
    case ca
    case ma
    case dz
    case tn
    case sn
    case ci
    case lu

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fr: "France"
        case .be: "Belgique"
        case .ch: "Suisse"
        case .ca: "Canada"
        case .ma: "Maroc"
        case .dz: "Algérie"
        case .tn: "Tunisie"
        case .sn: "Sénégal"
        case .ci: "Côte d'Ivoire"
        case .lu: "Luxembourg"
        }
    }

    var flag: String {
        switch self {
        case .fr: "🇫🇷"
        case .be: "🇧🇪"
        case .ch: "🇨🇭"
        case .ca: "🇨🇦"
        case .ma: "🇲🇦"
        case .dz: "🇩🇿"
        case .tn: "🇹🇳"
        case .sn: "🇸🇳"
        case .ci: "🇨🇮"
        case .lu: "🇱🇺"
        }
    }

    /// Le système scolaire, dit en trois mots. C'est ce qui justifie la question.
    var systemHint: String {
        switch self {
        case .fr: "Brevet, bac, prépa, PASS"
        case .be: "CESS, bachelier, master"
        case .ch: "Maturité, bachelor, master"
        case .ca: "Secondaire, cégep, université"
        case .ma: "Bac marocain, prépa, concours"
        case .dz: "Bac algérien, licence, master"
        case .tn: "Bac tunisien, licence, mastère"
        case .sn: "Bac, licence, grandes écoles"
        case .ci: "Bac, licence, grandes écoles"
        case .lu: "Diplôme de fin d'études, bachelor"
        }
    }

    /// Ce que Micabo suppose quand la question n'a pas été posée : c'est le pays de la
    /// grande majorité des utilisateurs, et le seul que l'app connaissait avant.
    static let fallback = SchoolingCountry.fr
}

/// Rapport de l'étudiant à l'oubli.
///
/// Quatre réponses là où il n'y avait qu'un oui et un non. Une question fermée à deux
/// branches sur un sujet aussi personnel force la caricature : celui qui retient bien
/// quand il s'y prend correctement n'est ni « oui, tout le temps » ni « non, ça va », et
/// devant deux cases il choisit celle qui le décrit le moins mal, ce qui ne renseigne
/// personne. Les deux réponses du milieu sont d'ailleurs les plus utiles : elles disent
/// que le problème est la méthode, ce que Micabo apporte.
enum ForgettingHabit: String, CaseIterable, Identifiable {
    case always
    case withMethod
    case sometimes
    case never

    var id: String { rawValue }

    var title: String {
        switch self {
        case .always: "Oui, tout le temps"
        case .withMethod: "Oui, mais quand j'ai les bonnes méthodes je retiens bien"
        case .sometimes: "Non, mais ça m'arrive d'oublier des notions"
        case .never: "Non, jamais"
        }
    }

    /// Un emoji par réponse : on retrouve la sienne d'un regard, sans relire quatre
    /// phrases qui commencent toutes par oui ou par non.
    var emoji: String {
        switch self {
        case .always: "😮‍💨"
        case .withMethod: "🧭"
        case .sometimes: "🤔"
        case .never: "😌"
        }
    }

    /// Ce que la réponse dit en oui ou non, pour le réglage historique.
    var forgetsOften: Bool {
        self == .always || self == .withMethod
    }
}

/// Réponses de l'onboarding, conservées localement pour personnaliser l'app.
enum OnboardingPreferences {
    enum Key {
        static let completed = "micabo.onboarding.completed"
        static let level = "micabo.onboarding.level"
        static let country = "micabo.onboarding.country"
        static let goal = "micabo.onboarding.goal"
        static let goals = "micabo.onboarding.goals"
        static let forgetting = "micabo.onboarding.forgetting"
        static let forgetsOften = "micabo.onboarding.forgetsOften"
        static let subjects = "micabo.onboarding.subjects"
        static let institutionId = "micabo.onboarding.institutionId"
        static let institutionName = "micabo.onboarding.institutionName"
        static let dailyMinutes = "micabo.onboarding.dailyMinutes"
        static let notificationsOptIn = "micabo.onboarding.notificationsOptIn"
        static let completedAt = "micabo.onboarding.completedAt"

        static let all = [
            completed, level, country, goal, goals, forgetting, forgetsOften, subjects,
            institutionId, institutionName,
            dailyMinutes, notificationsOptIn, completedAt
        ]
    }

    private static var defaults: UserDefaults { .standard }

    static var isCompleted: Bool {
        get { defaults.bool(forKey: Key.completed) }
        set { defaults.set(newValue, forKey: Key.completed) }
    }

    static var level: String? {
        get { defaults.string(forKey: Key.level) }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: Key.level)
            } else {
                defaults.removeObject(forKey: Key.level)
            }
        }
    }

    /// Le stade d'étude, tel que le reste de l'app le lit.
    ///
    /// Il est demandé à l'inscription et se corrige dans les réglages : c'est lui qui dit au
    /// modèle pour qui il écrit, et on change d'année.
    static var studyLevel: StudyLevel? {
        get { level.flatMap(StudyLevel.init(rawValue:)) }
        set { level = newValue?.rawValue }
    }

    /// Le pays de scolarisation. Absent, on suppose la France : c'est ce que l'app faisait
    /// implicitement avant de poser la question.
    static var schoolingCountry: SchoolingCountry {
        get {
            defaults.string(forKey: Key.country)
                .flatMap(SchoolingCountry.init(rawValue:)) ?? .fallback
        }
        set { defaults.set(newValue.rawValue, forKey: Key.country) }
    }

    /// Vrai quand la question a été posée. Sert aux réglages, pour distinguer un choix d'un
    /// défaut.
    static var hasChosenCountry: Bool {
        defaults.string(forKey: Key.country) != nil
    }

    /// Objectifs déclarés. Une seule réponse était possible auparavant : la clé
    /// historique est relue tant que la nouvelle n'a pas été écrite.
    static var goals: [String] {
        get {
            if let stored = defaults.stringArray(forKey: Key.goals) { return stored }
            return defaults.string(forKey: Key.goal).map { [$0] } ?? []
        }
        set { defaults.set(newValue, forKey: Key.goals) }
    }

    static var learningGoals: [LearningGoal] {
        goals.compactMap(LearningGoal.init(rawValue:))
    }

    /// La réponse détaillée à la question de l'oubli.
    static var forgetting: ForgettingHabit? {
        get { defaults.string(forKey: Key.forgetting).flatMap(ForgettingHabit.init(rawValue:)) }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Key.forgetting)
            } else {
                defaults.removeObject(forKey: Key.forgetting)
            }
        }
    }

    /// Le même rapport à l'oubli, en oui ou non. Conservé parce que la clé est déjà posée
    /// sur les appareils qui ont fait le parcours à deux réponses.
    static var forgetsOften: Bool? {
        get {
            guard defaults.object(forKey: Key.forgetsOften) != nil else { return nil }
            return defaults.bool(forKey: Key.forgetsOften)
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.forgetsOften)
            } else {
                defaults.removeObject(forKey: Key.forgetsOften)
            }
        }
    }

    static var subjects: [String] {
        get { defaults.stringArray(forKey: Key.subjects) ?? [] }
        set { defaults.set(newValue, forKey: Key.subjects) }
    }

    static var institutionId: String? {
        get { defaults.string(forKey: Key.institutionId) }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: Key.institutionId)
            } else {
                defaults.removeObject(forKey: Key.institutionId)
            }
        }
    }

    static var institutionName: String? {
        get { defaults.string(forKey: Key.institutionName) }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: Key.institutionName)
            } else {
                defaults.removeObject(forKey: Key.institutionName)
            }
        }
    }

    /// Objectif quotidien en minutes. 15 minutes par défaut, comme le curseur.
    static var dailyMinutes: Int {
        get {
            let stored = defaults.integer(forKey: Key.dailyMinutes)
            return stored == 0 ? 15 : stored
        }
        set { defaults.set(newValue, forKey: Key.dailyMinutes) }
    }

    static var notificationsOptIn: Bool {
        get { defaults.bool(forKey: Key.notificationsOptIn) }
        set { defaults.set(newValue, forKey: Key.notificationsOptIn) }
    }

    static func markCompleted() {
        defaults.set(Date(), forKey: Key.completedAt)
        isCompleted = true
    }

    /// Remet le parcours à zéro (bouton de test dans les réglages).
    static func reset() {
        Key.all.forEach(defaults.removeObject(forKey:))
    }
}
