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
        title(locale: .resolved())
    }

    func title(locale: UiLocale) -> String {
        L10n.t("ios.goal.\(rawValue)", locale: locale)
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
/// **C'est la première question du parcours**, avant même « tu en es où ? », et cet ordre
/// est le fond de l'affaire : parler français ne dit pas dans quel système on étudie, et
/// surtout les paliers d'études n'existent pas partout. « Les attendus du bac » ne veut rien
/// dire pour un lycéen belge, un étudiant québécois ne passe pas de concours de première
/// année de santé, « baccalauréat » désigne au Québec un diplôme universitaire, et proposer
/// « Prépa » ou « PASS » à un Américain ne lui laisse aucune réponse juste. Le pays commande
/// donc les réponses du niveau (`stages`) et la langue de rédaction (`language`).
///
/// La liste n'est pas mondiale, et `other` est là pour ça : elle couvre les pays où l'on
/// étudie en français, plus les deux systèmes anglophones les plus demandés, et retombe
/// ailleurs sur une échelle générique. Le drapeau tient lieu d'icône, parce qu'il se
/// reconnaît plus vite que son nom.
enum SchoolingCountry: String, CaseIterable, Identifiable {
    // **L'ordre de déclaration est l'ordre des pastilles**, et il n'est pas alphabétique :
    // ce sont les marchés visés en premier qui se lisent en premier. Les pays francophones
    // historiques suivent, parce qu'ils restent servis mais ne sont plus ce qu'on cherche
    // d'abord.
    case fr
    case uk
    case de
    case it
    case es
    case pt
    case cz
    case nl
    case gr
    case hu
    case pl
    case ro
    case se
    case tr

    case be
    case ch
    case ca
    case lu
    case ma
    case dz
    case tn
    case sn
    case ci
    case us

    /// Un pays hors liste. Il n'a plus d'échelle inventée : l'écran ouvre un champ de
    /// recherche sur tous les pays du monde, et le nom choisi est conservé à côté.
    case other

    var id: String { rawValue }

    func localizedName(locale: UiLocale) -> String {
        let key = "country.\(rawValue)"
        let translated = L10n.t(key, locale: locale)
        return translated == key ? name : translated
    }

    var name: String {
        switch self {
        case .fr: "France"
        case .uk: "Royaume-Uni"
        case .de: "Allemagne"
        case .it: "Italie"
        case .es: "Espagne"
        case .pt: "Portugal"
        case .cz: "Tchéquie"
        case .nl: "Pays-Bas"
        case .gr: "Grèce"
        case .hu: "Hongrie"
        case .pl: "Pologne"
        case .ro: "Roumanie"
        case .se: "Suède"
        case .tr: "Turquie"
        case .be: "Belgique"
        case .ch: "Suisse"
        case .ca: "Canada"
        case .lu: "Luxembourg"
        case .ma: "Maroc"
        case .dz: "Algérie"
        case .tn: "Tunisie"
        case .sn: "Sénégal"
        case .ci: "Côte d'Ivoire"
        case .us: "États-Unis"
        case .other: "Autre pays"
        }
    }

    var flag: String {
        switch self {
        case .fr: "🇫🇷"
        case .uk: "🇬🇧"
        case .de: "🇩🇪"
        case .it: "🇮🇹"
        case .es: "🇪🇸"
        case .pt: "🇵🇹"
        case .cz: "🇨🇿"
        case .nl: "🇳🇱"
        case .gr: "🇬🇷"
        case .hu: "🇭🇺"
        case .pl: "🇵🇱"
        case .ro: "🇷🇴"
        case .se: "🇸🇪"
        case .tr: "🇹🇷"
        case .be: "🇧🇪"
        case .ch: "🇨🇭"
        case .ca: "🇨🇦"
        case .lu: "🇱🇺"
        case .ma: "🇲🇦"
        case .dz: "🇩🇿"
        case .tn: "🇹🇳"
        case .sn: "🇸🇳"
        case .ci: "🇨🇮"
        case .us: "🇺🇸"
        case .other: "🌍"
        }
    }

    /// Ce que Micabo suppose quand la question n'a pas été posée : c'est le pays de la
    /// grande majorité des utilisateurs, et le seul que l'app connaissait avant.
    static let fallback = SchoolingCountry.fr

    /// Code ISO de l'annuaire `institutions`. Le Royaume-Uni s'y écrit `GB`, pas `UK`.
    var institutionCountryIso: String? {
        switch self {
        case .other: nil
        case .uk: "GB"
        default: rawValue.uppercased()
        }
    }
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
        title(locale: .resolved())
    }

    func title(locale: UiLocale) -> String {
        L10n.t("ios.forget.\(rawValue)", locale: locale)
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
        /// Le palier tel qu'il se nomme dans le pays choisi. `level` reste écrit à côté :
        /// c'est lui que la fonction lit, et lui que le cloud synchronise.
        static let stage = "micabo.onboarding.stage"
        /// Sa marche sur l'échelle comparable d'un pays à l'autre. Elle est écrite parce que
        /// c'est elle qui retrouve le palier après un changement de pays : sans elle, la
        /// relecture retombe sur le registre, qui ne distingue pas un collégien d'un lycéen.
        static let tier = "micabo.onboarding.tier"
        static let country = "micabo.onboarding.country"
        /// Le pays choisi dans la recherche, quand la réponse est « Autre pays ». On garde
        /// son code ISO plutôt que son nom : le nom dépend de la langue du téléphone, et
        /// celui d'un pays change plus souvent que ses deux lettres.
        static let customCountryCode = "micabo.onboarding.customCountryCode"
        static let goal = "micabo.onboarding.goal"
        static let goals = "micabo.onboarding.goals"
        static let forgetting = "micabo.onboarding.forgetting"
        static let forgetsOften = "micabo.onboarding.forgetsOften"
        static let subjects = "micabo.onboarding.subjects"
        static let institutionId = "micabo.onboarding.institutionId"
        static let institutionName = "micabo.onboarding.institutionName"
        static let dailyMinutes = "micabo.onboarding.dailyMinutes"
        static let ratingAsked = "micabo.onboarding.ratingAsked"
        /// Écrite par l'écran des rappels, qui n'existe plus. Elle reste listée pour que la
        /// remise à zéro l'efface sur les appareils qui ont fait l'ancien parcours : une clé
        /// oubliée dans les réglages est une clé qu'on retrouve un jour en croyant qu'elle
        /// veut encore dire quelque chose.
        static let retiredNotificationsOptIn = "micabo.onboarding.notificationsOptIn"
        static let completedAt = "micabo.onboarding.completedAt"
        static let sheetLanguage = "micabo.onboarding.sheetLanguage"

        static let all = [
            completed, level, stage, tier, country, customCountryCode,
            goal, goals, forgetting, forgetsOften, subjects,
            institutionId, institutionName,
            dailyMinutes, ratingAsked, retiredNotificationsOptIn, completedAt,
            sheetLanguage
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

    /// L'identifiant du palier choisi, dans les termes du pays.
    static var educationStageId: String? {
        get { defaults.string(forKey: Key.stage) }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: Key.stage)
            } else {
                defaults.removeObject(forKey: Key.stage)
            }
        }
    }

    /// La marche du palier choisi, écrite à côté de son identifiant.
    static var educationTier: EducationTier? {
        get { defaults.string(forKey: Key.tier).flatMap(EducationTier.init(rawValue:)) }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Key.tier)
            } else {
                defaults.removeObject(forKey: Key.tier)
            }
        }
    }

    /// Le palier d'études, résolu dans le pays courant.
    ///
    /// Écrire le palier écrit aussi sa marche et son registre. Les trois servent à des choses
    /// différentes et aucun ne remplace les autres : l'identifiant retrouve la réponse exacte,
    /// la marche la retrouve dans un autre pays, et le registre est ce que la fonction reçoit
    /// et ce que le cloud synchronise.
    static var educationStage: EducationStage? {
        get {
            schoolingCountry.resolvedStage(
                id: educationStageId,
                tier: educationTier,
                level: studyLevel
            )
        }
        set {
            educationStageId = newValue?.id
            educationTier = newValue?.tier
            studyLevel = newValue?.level
        }
    }

    /// La langue choisie pour les fiches, quand elle n'est plus celle du pays.
    static var sheetLanguage: ContentLanguage? {
        get { defaults.string(forKey: Key.sheetLanguage).flatMap(ContentLanguage.init(rawValue:)) }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Key.sheetLanguage)
            } else {
                defaults.removeObject(forKey: Key.sheetLanguage)
            }
        }
    }

    /// La langue dans laquelle Micabo écrit.
    ///
    /// Un réglage explicite (web ou iOS) gagne. Sinon on retombe sur celle du pays
    /// de scolarisation, comme avant qu'on puisse la changer.
    static var contentLanguage: ContentLanguage {
        sheetLanguage ?? schoolingCountry.language
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

    /// Le pays nommé à la main, quand la réponse est « Autre pays ».
    ///
    /// Il n'a pas de système scolaire connu et ne change donc ni les paliers ni la langue :
    /// il sert à savoir **qui utilise Micabo**, ce qui est la seule question à laquelle une
    /// liste de pays ouverte puisse répondre honnêtement.
    static var customCountry: WorldCountry? {
        get { WorldCountries.country(code: defaults.string(forKey: Key.customCountryCode)) }
        set {
            if let newValue {
                defaults.set(newValue.code, forKey: Key.customCountryCode)
            } else {
                defaults.removeObject(forKey: Key.customCountryCode)
            }
        }
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

    /// Vrai dès que la note a été demandée une fois.
    ///
    /// Le système limite déjà les demandes de note à trois par an et ignore les suivantes en
    /// silence — mais il les ignore *après* les avoir comptées. Sans ce drapeau, quelqu'un
    /// qui refait le parcours brûlerait ses trois demandes de l'année sur le même écran, et
    /// il n'en resterait aucune pour le moment où l'app aura vraiment rendu service.
    static var ratingAsked: Bool {
        get { defaults.bool(forKey: Key.ratingAsked) }
        set { defaults.set(newValue, forKey: Key.ratingAsked) }
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
