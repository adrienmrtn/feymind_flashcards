import SwiftUI

// MARK: - Les modes de la caméra

/// **Ce que Mika fait d'une page photographiée** (lot 12). Le mode se choisit par les pastilles
/// au-dessus du déclencheur, et l'app s'en souvient d'une fois sur l'autre (`ScanModeMemory`).
///
/// Tous passent par le serveur déployé, sans fonction nouvelle : la page est **lue sur
/// l'appareil** (Vision), son texte part en document joint, et la consigne du mode part en
/// message de l'élève dans `mika-chat` — sauf « Cartes mémoire », qui demande les cartes à
/// `generate-flashcards`. « Résoudre », ouvert depuis la caméra seule, garde le scanner pas à
/// pas qu'on connaît (`SolverSolutionView`). Une capture = **une** question Mika, la porte de
/// toujours (`MikaQuota`).
///
/// Les noms partent tels quels dans les statistiques : des valeurs fixes, jamais le texte lu.
enum ScanMode: String, CaseIterable, Identifiable, Codable {
    case solve
    case equation
    case explain
    case vocabulary
    case translate
    case flashcards
    case summary

    var id: String { rawValue }

    /// L'ordre des pastilles : résoudre d'abord (le geste d'avant), puis comprendre, puis
    /// apprendre.
    static let ordered: [ScanMode] = [.solve, .equation, .explain, .summary, .translate, .vocabulary, .flashcards]

    /// Le nom de la pastille.
    func title(locale: UiLocale = .resolved()) -> String {
        L10n.t("ios.scan12.mode.\(rawValue)", locale: locale)
    }

    /// La phrase d'aide, au-dessus du cadre : ce qu'il faut viser.
    func hint(locale: UiLocale = .resolved()) -> String {
        L10n.t("ios.scan12.hint.\(rawValue)", locale: locale)
    }

    var symbol: String {
        switch self {
        case .solve: "checkmark.seal.fill"
        case .equation: "function"
        case .explain: "lightbulb.fill"
        case .vocabulary: "character.book.closed.fill"
        case .translate: "character.bubble.fill"
        case .flashcards: "rectangle.on.rectangle.angled.fill"
        case .summary: "text.alignleft"
        }
    }

    /// La couleur de l'idée (`COMMON.md` § 5).
    var tone: Color {
        switch self {
        case .solve: V3Color.iconGreen
        case .equation: V3Color.iconBlue
        case .explain: V3Color.iconYellow
        case .vocabulary: V3Color.iconPink
        case .translate: V3Color.iconLilac
        case .flashcards: V3Color.iconOrange
        case .summary: V3Color.iconBlue
        }
    }

    /// **Le cadrage.** Une question se cadre seule (le cadre réglable du scanner) ; une
    /// équation tient dans une bande ; le reste prend la page entière, et plusieurs à la suite.
    var framing: ScanFraming {
        switch self {
        case .solve: .question
        case .equation: .line
        default: .page
        }
    }

    /// Plusieurs pages à la suite : tout ce qui se lit en page.
    var takesSeveralPages: Bool { framing == .page }

    /// Les modes qui rendent des cartes à ranger dans une leçon.
    var makesCards: Bool { self == .vocabulary || self == .flashcards }

    var analyticsName: String { rawValue }

    /// Les cartes demandées à `generate-flashcards` pour une page : de quoi tenir une révision,
    /// pas de quoi noyer la page.
    static let cardCount = 8
}

/// Le cadre posé sur la visée.
enum ScanFraming: Equatable {
    /// Le cadre réglable du scanner, autour d'une seule question.
    case question
    /// Une bande large et basse, pour une ligne de calcul.
    case line
    /// Le contour d'une page entière, fixe.
    case page
}

// MARK: - La mémoire du mode

/// **Le mode et la langue cible, retenus d'une fois sur l'autre** : on rouvre la caméra comme
/// on l'a laissée. Sur l'appareil seulement.
struct ScanModeMemory {
    var defaults: UserDefaults = .standard

    enum Key {
        static let mode = "micabo.scan12.mode"
        static let target = "micabo.scan12.translateTarget"
    }

    var mode: ScanMode {
        get { defaults.string(forKey: Key.mode).flatMap(ScanMode.init(rawValue:)) ?? .solve }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.mode) }
    }

    /// La langue vers laquelle traduire : celle choisie la dernière fois, sinon celle de l'app.
    func target(appLocale: UiLocale = .resolved()) -> UiLocale {
        if let raw = defaults.string(forKey: Key.target), let saved = UiLocale(rawValue: raw), ScanTranslation.targets.contains(saved) {
            return saved
        }
        return ScanTranslation.defaultTarget(for: appLocale)
    }

    func remember(target: UiLocale) {
        defaults.set(target.rawValue, forKey: Key.target)
    }
}

// MARK: - La traduction

/// **Les langues vers lesquelles Mika traduit**, celles où l'app sait écrire sa consigne.
///
/// La consigne de traduction est **écrite dans la langue cible** : `mika-chat` répond dans la
/// langue du dernier message de l'élève (sa règle la plus forte), et une consigne en français
/// qui demanderait de l'anglais ferait répondre en français.
enum ScanTranslation {
    static let targets: [UiLocale] = [.fr, .en, .de, .es, .tr, .ar]

    /// La langue de l'app, quand Mika sait y traduire ; l'anglais sinon.
    static func defaultTarget(for appLocale: UiLocale) -> UiLocale {
        if targets.contains(appLocale) { return appLocale }
        let base = UiLocale.allCases.first { $0.rawValue == String(appLocale.rawValue.prefix(2)) }
        if let base, targets.contains(base) { return base }
        return .en
    }

    /// Le nom de la langue, dans la langue de l'app : « anglais » au fil d'une phrase,
    /// « Anglais » seul dans un menu (« Englisch » dans les deux cas).
    static func name(of target: UiLocale, in locale: UiLocale = .resolved(), capitalized: Bool = true) -> String {
        let code = String(target.rawValue.prefix(2))
        let name = Locale(identifier: locale.bcp47).localizedString(forLanguageCode: code) ?? code
        return capitalized ? name.capitalized(with: Locale(identifier: locale.bcp47)) : name
    }
}

// MARK: - Les consignes

/// **Ce qu'on demande à Mika, mode par mode.** Des fonctions pures : elles se testent sans
/// réseau. La page lue voyage dans le document joint ; ce qui est ici est la question.
enum ScanPrompts {
    /// La consigne envoyée au nom de l'élève. `typed` : ce que l'élève a tapé à la place d'une
    /// photo (ou en plus), mis à la suite.
    static func consigne(_ mode: ScanMode, target: UiLocale? = nil, typed: String = "", level: String? = HomeworkLevel.current, locale: UiLocale = .resolved()) -> String {
        let base: String
        switch mode {
        case .translate:
            // Dans la langue cible : c'est elle que Mika parlera.
            let into = target ?? ScanTranslation.defaultTarget(for: locale)
            base = L10n.t("ios.scan12.prompt.translate", locale: into)
        default:
            base = HomeworkLevel.appending(level, to: L10n.t("ios.scan12.prompt.\(mode.rawValue)", locale: locale))
        }
        let extra = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        let joined = extra.isEmpty ? base : base + "\n\n" + extra
        return String(joined.prefix(MikaLimits.messageCharacters))
    }

    /// Ce que la bulle de l'élève montre : le nom du geste, pas la consigne entière.
    static func label(_ mode: ScanMode, target: UiLocale? = nil, locale: UiLocale = .resolved()) -> String {
        switch mode {
        case .translate:
            let into = target ?? ScanTranslation.defaultTarget(for: locale)
            return L10n.t("ios.scan12.label.translate", locale: locale, vars: ["language": ScanTranslation.name(of: into, in: locale, capitalized: false)])
        default:
            return L10n.t("ios.scan12.label.\(mode.rawValue)", locale: locale)
        }
    }

    /// Le titre de la conversation : le geste, puis le début de la page.
    static func threadTitle(_ mode: ScanMode, target: UiLocale? = nil, firstText: String, locale: UiLocale = .resolved()) -> String {
        let label = Self.label(mode, target: target, locale: locale)
        let line = firstText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.count >= 3 } ?? ""
        guard !line.isEmpty else { return label }
        return ChatTitle.shortened("\(label) · \(line)")
    }
}

// MARK: - Les cartes d'un vocabulaire

/// **Les mots que Mika a relevés**, lus dans sa réponse. La consigne lui demande un paragraphe
/// par mot, qui commence par le mot en gras suivi de deux-points : on en tire une carte (le mot
/// au recto, sa définition au verso), sans changer le serveur.
enum ScanCardParser {
    static let maxCards = 12

    static func vocabulary(from reply: String) -> [GeneratedFlashcard] {
        var cards: [GeneratedFlashcard] = []
        for paragraph in reply.components(separatedBy: "\n") {
            let line = paragraph.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("**") else { continue }
            let rest = line.dropFirst(2)
            guard let close = rest.range(of: "**") else { continue }
            var term = String(rest[..<close.lowerBound]).trimmingCharacters(in: .whitespaces)
            var tail = String(rest[close.upperBound...]).trimmingCharacters(in: .whitespaces)
            // Les deux-points, dedans ou après le gras : « **mot :** » comme « **mot** : ».
            for colon in [":", "：", "؛"] {
                if term.hasSuffix(colon) { term = String(term.dropLast()).trimmingCharacters(in: .whitespaces) }
                if tail.hasPrefix(colon) { tail = String(tail.dropFirst()).trimmingCharacters(in: .whitespaces) }
            }
            // L'exemple en italique ne va pas sur la carte : la définition seule.
            if let example = tail.range(of: " *") ?? tail.range(of: "*") {
                tail = String(tail[..<example.lowerBound])
            }
            let definition = tail.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-–")))
            guard !term.isEmpty, term.count <= 60, definition.count >= 3 else { continue }
            cards.append(GeneratedFlashcard(front: term, back: definition))
            if cards.count == maxCards { break }
        }
        return cards
    }
}

// MARK: - La lampe

/// **Le bouton de la lampe** : seulement quand l'appareil en a une, et que la visée tourne.
enum ScanTorch {
    static func isShown(hasTorch: Bool, cameraAvailable: Bool, live: Bool) -> Bool {
        hasTorch && cameraAvailable && live
    }
}
