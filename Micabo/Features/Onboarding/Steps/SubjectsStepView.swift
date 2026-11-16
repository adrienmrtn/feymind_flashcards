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

    /// Le catalogue général, sans ce que la classe propose déjà.
    private var others: [String] {
        let known = Set(mine)
        return SubjectCatalog.allSubjects.filter { !known.contains($0) }
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
                    chips(others)
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
            return inside.isEmpty ? nil : Entry(group: group, subjects: inside)
        }
    }

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

    /// L'icône d'une matière : celle de l'app (`MicaboIcon.subjectIcon`), sinon celle de son
    /// groupe.
    static func icon(for subject: String, country: SchoolingCountry) -> MicaboIcon {
        let text = folded(subject)
        if sportKeys.contains(where: text.contains) || Set(text.split { !$0.isLetter }.map(String.init)).contains("eps") {
            return .trophy
        }
        if let icon = MicaboIcon.subjectIcon(subject) { return icon }
        switch of(subject, country: country) {
        case .languages: return .language
        case .other: return .star
        case .main: return .book
        }
    }

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
            i18n.t("ios.onb16.q.hardest"),
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
