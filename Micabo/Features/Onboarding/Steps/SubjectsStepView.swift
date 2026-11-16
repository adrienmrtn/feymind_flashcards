import SwiftUI

/// **« Tes matières cette année ? »** Choix multiple.
///
/// L'écran propose **les matières de la classe qu'on vient de déclarer** : un élève de
/// terminale voit les siennes et coche en trois secondes. Le catalogue général reste à un
/// appui (« Autres matières »). Mika reprend la classe, puis réagit dès la première coche.
///
/// **Lot 16 (« trie-les un peu mieux, avec une icône, et en plus petit »)** : les matières de
/// la classe sont rangées en trois groupes — les matières principales, les langues, puis le
/// reste (sport, arts, éducation civique, oral) —, chacune avec l'icône de sa matière, dans des
/// puces plus petites. L'ordre de la classe est gardé à l'intérieur de chaque groupe.
struct SubjectsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var showsCatalog = false

    /// Les matières de la classe déclarée, vides quand on n'en sait pas assez.
    private var mine: [String] {
        Self.classSubjects(for: model)
    }

    /// Le catalogue se montre quand la classe n'a pas de liste, quand l'élève le demande, ou
    /// quand une matière déjà cochée s'y trouve (un retour sur l'écran).
    private var showsOthers: Bool {
        mine.isEmpty || showsCatalog || !model.subjects.isSubset(of: Set(mine))
    }

    private var hasAnswer: Bool {
        !model.subjects.isEmpty
    }

    private var say: OnbSay {
        if hasAnswer {
            return OnbSay(i18n.t("ios.onb10.react.subjects"), mood: .write)
        }
        if !mine.isEmpty, let label = model.classLabel {
            return OnbSay(i18n.t("ios.onb12.say.subjectsOf", ["class": label]), mood: .idle)
        }
        return OnbSay(i18n.t("ios.onb12.say.subjects"), mood: .idle)
    }

    var body: some View {
        OnbQuestion(i18n.t("ios.onb12.q.subjects"), say: say) {
            VStack(alignment: .leading, spacing: 16) {
                if !mine.isEmpty {
                    let groups = OnbSubjectGroup.grouped(mine, country: model.country)
                    ForEach(groups, id: \.group) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            // Un intitulé seulement quand il y a plusieurs groupes.
                            if groups.count > 1 {
                                header(i18n.t(entry.group.titleKey))
                            }
                            chips(entry.subjects)
                        }
                    }
                }

                if showsOthers {
                    if !mine.isEmpty {
                        header(i18n.t("ios.onb10.subjects.more"))
                            .padding(.top, 4)
                    }
                    // Le catalogue (licence, master, pays non décrit) : rangé par domaine —
                    // sciences, santé, sciences humaines, langues, droit et économie, technique —,
                    // sous les mêmes petits intitulés, plutôt qu'en une longue liste mêlée.
                    let known = Set(mine)
                    ForEach(SubjectCatalog.families) { family in
                        let subjects = family.subjects.filter { !known.contains($0) }
                        if !subjects.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                header(SubjectDisplay.family(family.name, locale: i18n.locale))
                                chips(subjects)
                            }
                        }
                    }
                } else {
                    V3Chip(i18n.t("ios.onb10.subjects.more"), systemImage: "plus") {
                        withAnimation(MicaboMotion.standard) { showsCatalog = true }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } footer: {
            V3Button(i18n.t("common.continue"), isEnabled: hasAnswer) {
                model.advance()
            }
        }
    }

    /// Un petit intitulé de groupe, au corps des mentions, en gris (pas en bleu).
    private func header(_ text: String) -> some View {
        Text(text)
            .font(OnbType.mention.weight(.semibold))
            .foregroundStyle(V3Color.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    /// **Les matières de la classe de l'élève** (`SchoolSubjects.forYear`), ou rien quand le
    /// pays n'est pas décrit : on ne rend pas une liste inventée.
    static func classSubjects(for model: OnboardingModel) -> [String] {
        guard SchoolSystem.isDetailed(model.country, custom: model.customCountry) else { return [] }
        return SchoolSubjects.forYear(
            trackID: model.track?.id,
            yearID: model.year?.id,
            country: model.country
        ) ?? []
    }

    private func chips(_ subjects: [String]) -> some View {
        MicaboFlowLayout(spacing: 7, lineSpacing: 8) {
            ForEach(subjects, id: \.self) { subject in
                OnbSubjectChip(
                    title: SubjectDisplay.subject(subject, locale: i18n.locale),
                    icon: OnbSubjectGroup.icon(for: subject, country: model.country),
                    isSelected: model.subjects.contains(subject)
                ) {
                    toggle(subject)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ subject: String) {
        withAnimation(MicaboMotion.quick) {
            if model.subjects.contains(subject) {
                model.subjects.remove(subject)
            } else {
                model.subjects.insert(subject)
            }
        }
    }
}

// MARK: - Les groupes de matières

/// **Le groupe d'une matière** (lot 16) : les matières principales, les langues étrangères,
/// et le reste (sport, arts, musique, éducation civique, oral, brevet). Le classement lit le
/// nom de la matière, dans les langues des systèmes scolaires décrits ; la langue du pays
/// (« Français » en France, « English » au Royaume-Uni) reste une matière principale.
enum OnbSubjectGroup: Int, CaseIterable, Comparable {
    case main
    case languages
    case other

    static func < (lhs: OnbSubjectGroup, rhs: OnbSubjectGroup) -> Bool { lhs.rawValue < rhs.rawValue }

    var titleKey: String {
        switch self {
        case .main: "ios.onb16.subjects.main"
        case .languages: "ios.onb16.subjects.languages"
        case .other: "ios.onb16.subjects.other"
        }
    }

    struct Entry {
        let group: OnbSubjectGroup
        let subjects: [String]
    }

    /// Les matières d'une classe, rangées par groupe, l'ordre de la classe gardé dans chacun.
    static func grouped(_ subjects: [String], country: SchoolingCountry) -> [Entry] {
        let tagged = subjects.map { ($0, of($0, country: country)) }
        return allCases.compactMap { group in
            let inside = tagged.filter { $0.1 == group }.map(\.0)
            guard !inside.isEmpty else { return nil }
            return Entry(group: group, subjects: group == .main ? ordered(inside, country: country) : inside)
        }
    }

    /// **L'ordre des matières principales** (retour du lot 16) : le tronc commun d'abord —
    /// les maths, la langue du pays, les sciences, l'histoire-géographie, la philosophie —,
    /// puis les spécialités et options, chaque rang gardant l'ordre de la classe.
    static func ordered(_ subjects: [String], country: SchoolingCountry) -> [String] {
        subjects.enumerated()
            .sorted { lhs, rhs -> Bool in
                let a = rank(lhs.element, country: country), b = rank(rhs.element, country: country)
                return a != b ? a < b : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// Le rang d'une matière dans le tronc commun ; 5 pour une spécialité ou une option.
    static func rank(_ subject: String, country: SchoolingCountry) -> Int {
        let text = folded(subject)
        let words = Set(text.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        if specialtyKeys.contains(where: text.contains) || !words.isDisjoint(with: specialtyWords) { return 5 }
        if mathKeys.contains(where: text.contains) { return 0 }
        if isNative(text, country: country) { return 1 }
        if scienceKeys.contains(where: text.contains) { return 2 }
        if humanitiesKeys.contains(where: text.contains) { return 3 }
        if philosophyKeys.contains(where: text.contains) { return 4 }
        return 5
    }

    private static let specialtyKeys = [
        "complement", "expert", "further", "hggsp", "ingenieur", "computer", "informati", "econom", "business",
        "politi", "government", "psycholog", "sociolog", "droit", "management", "wirtschaft",
    ]
    private static let specialtyWords: Set<String> = ["ses", "hlp", "nsi", "llcer"]
    private static let mathKeys = ["math", "algebr", "geometr", "calcul", "matemat", "wiskunde"]
    private static let scienceKeys = [
        "physi", "chimi", "chemi", "svt", "biolog", "scientifi", "science", "naturwiss", "fisica", "quimica",
    ]
    private static let humanitiesKeys = ["histoir", "history", "histori", "geschicht", "storia", "geograph", "erdkunde"]
    private static let philosophyKeys = ["philo", "filosof", "ethik"]

    /// Le groupe d'une matière.
    static func of(_ subject: String, country: SchoolingCountry) -> OnbSubjectGroup {
        let text = folded(subject)
        let words = Set(text.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        if !words.isDisjoint(with: otherWords) || otherKeys.contains(where: text.contains) {
            return .other
        }
        if languageKeys.contains(where: text.contains), !isNative(text, country: country) {
            return .languages
        }
        return .main
    }

    /// **L'icône d'une matière** (retour du lot 16 : « plus de livre rouge partout ») : toutes
    /// les langues étrangères portent la même (`.language`), la langue du pays la plume ; puis
    /// une icône par domaine (santé, économie, informatique, ingénierie, politique et droit,
    /// astronomie, statistiques…), puis celle de l'app (`MicaboIcon.subjectIcon`), et seulement
    /// en dernier celle du groupe.
    static func icon(for subject: String, country: SchoolingCountry) -> MicaboIcon {
        let text = folded(subject)
        let words = Set(text.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        if sportKeys.contains(where: text.contains) || words.contains("eps") || words.contains("staps") {
            return .trophy
        }
        let group = of(subject, country: country)
        if group == .languages { return .language }
        if isNative(text, country: country) { return .quill }
        for (icon, keys, whole) in domainIcons where keys.contains(where: text.contains) || !words.isDisjoint(with: whole) {
            return icon
        }
        if let icon = MicaboIcon.subjectIcon(subject) { return icon == .book ? .language : icon }
        if ["scien", "naturwiss", "wissenschaft"].contains(where: text.contains) { return .flask }
        switch group {
        case .languages: return .language
        case .other: return .star
        case .main: return .book
        }
    }

    /// Les domaines, dans l'ordre : le premier reconnu gagne. La santé passe avant la physique
    /// (« physiologie »), l'ingénierie avant la mécanique, le politique avant l'économie
    /// (« Politik und Wirtschaft »), l'informatique avant les sciences.
    private static let domainIcons: [(MicaboIcon, [String], Set<String>)] = [
        (.health, ["medecin", "medicin", "medizin", "medic", "pharma", "anatom", "infirmi", "nursing", "kinesi",
                   "physiother", "nutrition", "dietet", "sante", "health", "gesundheit", "pflege", "enfermer",
                   "odonto", "dentist", "midwif", "sage-femme", "physiolog", "patholog", "st2s"], []),
        (.politics, ["hggsp", "geopolit", "politi", "government", "droit", "derecho", "diritto", "civique",
                     "citizenship", "civic", "sozialkunde", "gemeinschaftskunde", "ciudadania", "cittadinanza"],
         ["law", "emc", "jura", "recht"]),
        (.economy, ["econom", "business", "gestion", "management", "finance", "comptab", "accounting", "marketing",
                    "wirtschaft", "commerce", "ekonomi", "stmg"], ["ses", "bwl", "vwl"]),
        (.computer, ["informati", "computer", "programm", "algorith", "reseau", "network", "numerique", "coding",
                     "bilgisayar"], ["nsi", "snt", "ict"]),
        (.engineering, ["ingenieur", "engineer", "technolog", "technik", "electroni", "mecaniq", "mechanic",
                        "genie", "architect", "sti2d"], []),
        (.astronomy, ["astronom", "astrophys"], []),
        (.statistics, ["statisti"], []),
        (.globe, ["geolog", "earth science", "environment", "environnement"], []),
        (.palette, ["musical", "cinema", "film", "theatre", "danse", "dance", "photograph", "drama", "std2a"], []),
        (.quill, ["humanites", "journal", "linguisti", "redaction", "writing"], ["hlp"]),
        (.brain, ["pedagog", "religion", "religio", "anthropolog"], []),
        (.diploma, ["brevet", "grand oral"], ["oral"]),
        (.lightbulb, ["culture generale", "general knowledge"], []),
        (.check, ["code de la route"], []),
    ]

    private static func folded(_ text: String) -> String {
        text.lowercased().folding(options: .diacriticInsensitive, locale: nil)
    }

    /// La langue du pays : une matière principale, pas une langue étrangère.
    private static func isNative(_ text: String, country: SchoolingCountry) -> Bool {
        let native: [String] = switch country {
        case .fr, .be, .lu, .ch, .ma, .dz, .tn, .sn, .ci, .ca: ["francais", "french", "lettres"]
        case .uk, .us: ["english"]
        case .de: ["deutsch", "german"]
        case .es: ["castellan"]
        case .it: ["italiano"]
        case .pt: ["portugues"]
        case .nl: ["nederlands"]
        case .tr: ["turk"]
        case .pl: ["polski"]
        case .cz: ["cestina", "cesky"]
        case .gr: ["ελληνικ", "neoelli", "greek"]
        case .hu: ["magyar"]
        case .ro: ["romana", "romanian"]
        case .se: ["svenska"]
        default: []
        }
        return native.contains(where: text.contains)
    }

    /// Des mots entiers : trop courts pour être cherchés dans un nom.
    private static let otherWords: Set<String> = ["eps", "emc", "art", "arts", "pe", "musik", "musique", "music"]

    private static let sportKeys = [
        "sport", "education physique", "physical education", "educacion fisica", "educazione fisica",
        "beden egitimi", "wychowanie fizyczne", "lichamelijke", "idrott", "testneveles", "telesna", "liikunta",
    ]

    private static let otherKeys = sportKeys + [
        "civique", "citizenship", "civic", "ciudadania", "cittadinanza", "arts plastiques", "education musicale",
        "dessin", "grand oral", "brevet", "religion", "religio", "theatre", "danse", "dance", "musica", "muzik",
        "kunst", "beeldende", "zene", "rysunek",
    ]

    private static let languageKeys = [
        "anglais", "english", "englisch", "ingles", "inglese", "engels", "ingilizce", "angielski", "anglictina",
        "angol", "engleza", "engelska", "engelsk", "englanti", "inglise",
        "espagnol", "spanish", "spanisch", "espanol", "spagnolo", "hiszpanski", "spaans",
        "allemand", "german", "deutsch", "aleman", "tedesco", "almanca", "niemiecki", "duits",
        "italien", "italian", "italiano", "portugais", "portuguese", "latin", "latein", "grec ancien",
        "chinois", "chinese", "japonais", "japanese", "arabe", "arabic", "russe", "russian",
        "francais", "french", "franzosisch", "frances", "francese", "fransizca", "francuski", "frans",
        "llcer", "langue", "language", "sprache", "idioma", "lingua", "lv1", "lv2",
        "extranjera", "straniera", "fremdsprache", "foreign", "yabanci dil",
        "английск", "إنجليزية", "انجليزية", "فرنسية",
    ]
}

/// **Une matière en puce** (lot 16) : son icône, son nom, plus petite ; elle saute quand on la
/// coche.
struct OnbSubjectChip: View {
    let title: String
    var icon: MicaboIcon = .book
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let calm = reduceMotion
        let selected = isSelected
        let tone = LessonTone.forSubject(icon).ink
        Button(action: action) {
            HStack(spacing: 6) {
                MicaboIconView(icon: icon, size: 15 * 1.35, tint: tone)
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(V3Color.ink)
                    .lineLimit(1)
            }
            .padding(.leading, 9)
            .padding(.trailing, 12)
            .frame(minHeight: 36)
            .background(isSelected ? V3Color.accentWash : V3Color.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? V3Color.accent : V3Color.line, lineWidth: V3Metric.border))
            .contentShape(Capsule())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .selection))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .keyframeAnimator(initialValue: CGFloat(1), trigger: isSelected) { content, scale in
            content.scaleEffect(calm || !selected ? 1 : scale)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.08, duration: 0.1)
                SpringKeyframe(1.0, duration: 0.25)
            }
        }
    }
}

// MARK: - La matière la plus dure

/// **« Quelle matière est la plus difficile pour toi ? »** (lot 12, mots simples au lot 16) Une réponse, parmi ses
/// matières. C'est elle que prennent ensuite les démonstrations et la question d'essai : la
/// douleur est nommée, et la réponse de l'app y revient tout de suite.
struct HardestSubjectStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbQuestion(
            i18n.t("ios.onb17.q.hardest"),
            say: OnbSay(i18n.t("ios.onb16.say.hardest"), mood: .wink)
        ) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(model.subjects.sorted(), id: \.self) { subject in
                    OnbOption(
                        title: SubjectDisplay.subject(subject, locale: i18n.locale),
                        icon: MicaboIcon.subjectIcon(subject) ?? .book,
                        isSelected: model.hardestSubject == subject
                    ) {
                        OnbPick.choose(on: .hardestSubject, model: model) { model.hardestSubject = subject }
                    }
                }
            }
        }
    }
}
