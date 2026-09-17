import CoreGraphics
import Foundation

/// La fiche d'un cours : ce que Micabo écrit à partir du document importé.
///
/// Un import ne produit plus seulement des cartes. Il produit d'abord une **fiche**, qui est
/// ce que l'étudiant lit, et à partir de laquelle il peut, s'il le veut, demander des cartes.
///
/// Elle a porté douze blocs : définitions encadrées, encadrés de ton, étapes, chiffres clés,
/// questions cachées, tableaux, schémas, graphes, figures recadrées. Chacun avait son rendu,
/// et **c'était le problème** : une fiche ne ressemblait plus à un cours mis au propre mais à
/// une brochure, et surtout l'étudiant n'y pouvait rien changer - on ne modifie pas un
/// histogramme à la main. Restent quatre blocs, tous en texte :
///
/// | Bloc | Ce qu'il porte |
/// | --- | --- |
/// | `heading` | un titre de partie ou de sous-partie |
/// | `paragraph` | des phrases, ce dont une fiche est faite |
/// | `list` | une énumération, numérotée ou non |
/// | `formula` | une formule, parce qu'elle ne s'écrit pas en toutes lettres |
///
/// Tout le reste - ce qu'un tableau disait, ce qu'un encadré appuyait - s'écrit dans le
/// texte, avec le balisage en ligne : `**gras**`, `*italique*`, `==surligné==`. Les fiches
/// déjà enregistrées ne sont pas perdues pour autant : les anciens blocs sont **convertis** à
/// la lecture, jamais jetés. Une définition devient sa phrase, terme en gras ; un tableau
/// devient ses lignes ; un graphe devient ses valeurs.
struct CourseSheet: Codable, Equatable, Sendable {
    var blocks: [SheetBlock]

    init(blocks: [SheetBlock]) {
        self.blocks = blocks
    }

    var isEmpty: Bool {
        blocks.isEmpty
    }

    /// Le texte de la fiche, sans balisage : c'est ce qui part au modèle quand il faut
    /// écrire des cartes, et ce qui sert de contexte à l'explication d'un passage.
    func plainText() -> String {
        blocks.flatMap { $0.plainLines() }.joined(separator: "\n")
    }

    var wordCount: Int {
        plainText().split(whereSeparator: { $0 == " " || $0.isNewline }).count
    }

    /// Durée de lecture annoncée, sur une base de 200 mots par minute.
    var readingMinutes: Int {
        max(1, Int((Double(wordCount) / 200).rounded()))
    }

    /// Décode la fiche telle qu'elle a été enregistrée. Une fiche illisible vaut pas de
    /// fiche : l'écran du cours propose alors de la refaire.
    static func decode(from data: Data?) -> CourseSheet? {
        guard let data, !data.isEmpty else { return nil }
        guard let sheet = try? JSONDecoder().decode(CourseSheet.self, from: data) else { return nil }
        return sheet.isEmpty ? nil : sheet
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Nettoie tous les textes de la fiche : les tirets cadratins et les puces écrites à
    /// la main partent, le balisage en ligne reste, puisque c'est lui qui la met en forme.
    func sanitized() -> CourseSheet {
        CourseSheet(blocks: Array(blocks.compactMap { $0.sanitized() }.prefix(SheetLimits.blocks)))
    }

    // MARK: Codage

    private enum CodingKeys: String, CodingKey {
        case blocks
    }

    /// Un bloc mal formé ne doit pas emporter la fiche entière : il est simplement sauté.
    ///
    /// Il rend **une liste** et non un bloc, parce qu'un ancien bloc peut en valoir deux : un
    /// tableau devient son titre, puis ses lignes.
    private struct LenientBlock: Decodable {
        let blocks: [SheetBlock]

        init(from decoder: Decoder) throws {
            blocks = (try? SheetBlock.decodeConverting(from: decoder)) ?? []
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lenient = try container.decode([LenientBlock].self, forKey: .blocks)
        blocks = lenient.flatMap(\.blocks)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blocks, forKey: .blocks)
    }
}

// MARK: - Surlignage

/// Les couleurs de surligneur, dans l'ordre de la barre d'outils.
///
/// Cinq teintes, pas plus : au delà, une page surlignée devient un nuancier et plus rien n'y
/// ressort. **Le modèle les emploie selon un code** - la définition en jaune, le chiffre en
/// menthe, le mécanisme en bleu, l'exception en rose, le repère en lilas - parce qu'une fiche
/// d'un seul feutre ne dit rien de plus qu'une fiche sans feutre, et que personne ne recolore
/// soixante blocs à la main. Le code est écrit une seule fois, dans le prompt de
/// `generate-course`, et vaut pour les deux clients. L'étudiant recolore par-dessus.
enum SheetHighlight: String, Codable, Equatable, CaseIterable, Sendable {
    case jaune
    case menthe
    case bleu
    case rose
    case lilas

    /// Ce que vaut un `==texte==` sans couleur écrite.
    static let fallback: SheetHighlight = .jaune
}

/// La taille d'un fragment de texte, quand elle n'est pas celle de son bloc.
///
/// Deux valeurs de part et d'autre du corps courant, et pas une de plus : un passage qu'on
/// veut voir de loin en feuilletant, un aparté qu'on garde sans qu'il encombre. Une échelle
/// plus fine ferait de la fiche une mise en page, et une fiche dont on règle la typographie
/// est une fiche qu'on ne révise plus.
///
/// À ne pas confondre avec la taille de lecture, qui grossit toute la page sur un appareil :
/// celle-ci appartient à la fiche et suit le cours d'un écran à l'autre.
enum SheetTextSize: String, Codable, Equatable, CaseIterable, Sendable {
    case petit
    case grand

    /// Le facteur appliqué à la taille du bloc. Voir `.sheet-doc [data-size]` côté site :
    /// les deux rendus doivent donner la même page.
    var scale: CGFloat {
        switch self {
        case .petit: return 0.85
        case .grand: return 1.22
        }
    }
}

// MARK: - Blocs

/// Un bloc de la fiche. Le décodage est tolérant : un bloc d'un type inconnu, ou vidé de
/// son texte, est ignoré au lieu de faire échouer toute la fiche.
enum SheetBlock: Codable, Equatable, Sendable {
    /// Titre de partie (niveau 1) ou de sous-partie (niveau 2).
    case heading(level: Int, text: String)
    /// Paragraphe rédigé. C'est le bloc majoritaire d'une fiche : on lit des phrases,
    /// pas une suite de puces.
    case paragraph(text: String)
    /// Énumération, numérotée quand l'ordre compte.
    case list(ordered: Bool, items: [String])
    /// Formule mise en valeur, avec la légende de ses symboles.
    case formula(latex: String, caption: String?)

    // MARK: Texte brut

    func plainLines() -> [String] {
        switch self {
        case .heading(_, let text):
            return [SheetMarkup.plain(text)].filter { !$0.isEmpty }

        case .paragraph(let text):
            return [SheetMarkup.plain(text)].filter { !$0.isEmpty }

        case .list(let ordered, let items):
            let lines = items.map(SheetMarkup.plain).filter { !$0.isEmpty }
            guard ordered else { return lines }
            return lines.enumerated().map { "\($0.offset + 1). \($0.element)" }

        case .formula(let latex, let caption):
            let formula = FormulaRenderer.plain(latex)
            guard let caption = caption?.nilIfBlank else { return [formula] }
            return ["\(formula) (\(SheetMarkup.plain(caption)))"]
        }
    }

    // MARK: Nettoyage

    func sanitized() -> SheetBlock? {
        switch self {
        case .heading(let level, let text):
            guard let clean = SheetText.clean(text) else { return nil }
            return .heading(level: level <= 1 ? 1 : 2, text: clean)

        case .paragraph(let text):
            guard let clean = SheetText.clean(text), clean.count >= 12 else { return nil }
            return .paragraph(text: clean)

        case .list(let ordered, let items):
            let clean = items.compactMap(SheetText.clean)
            guard !clean.isEmpty else { return nil }
            return .list(ordered: ordered, items: Array(clean.prefix(SheetLimits.listItems)))

        case .formula(let latex, let caption):
            guard let clean = latex.nilIfBlank else { return nil }
            return .formula(latex: clean, caption: caption.flatMap(SheetText.clean))
        }
    }

    // MARK: Codage

    private enum CodingKeys: String, CodingKey {
        case type, level, text, term, title, items, caption, latex, ordered
        case tone, headers, rows, bars, unit, kind, layout, nodes, page, crop, image
    }

    /// Nom du bloc sur le fil. Les quatre premiers sont le vocabulaire actuel du prompt ;
    /// les suivants sont ceux des fiches déjà en base, qu'on lit encore.
    private enum Kind: String {
        case heading, paragraph, list, formula
        case definition, callout, steps, keypoints, qa, table, diagram, chart, figure
    }

    init(from decoder: Decoder) throws {
        let converted = try SheetBlock.decodeConverting(from: decoder)
        guard let first = converted.first else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Bloc de fiche vide.")
            )
        }
        self = first
    }

    /// Lit un bloc et rend **ce qu'il vaut dans le format actuel**, c'est-à-dire zéro, un ou
    /// deux blocs. C'est le pendant exact de `normalizeBlock` côté serveur : les deux doivent
    /// convertir de la même façon, sinon la même fiche se lit différemment selon l'appareil.
    static func decodeConverting(from decoder: Decoder) throws -> [SheetBlock] {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = (try? container.decode(String.self, forKey: .type))?
            .trimmingCharacters(in: .whitespaces)
            .lowercased() ?? ""

        guard let kind = Kind(rawValue: rawType) else { return [] }

        let title = ((try? container.decodeIfPresent(String.self, forKey: .title)) ?? nil).flatMap { $0.nilIfBlank }
        let text = (try? container.decode(String.self, forKey: .text)) ?? ""
        let caption = ((try? container.decodeIfPresent(String.self, forKey: .caption)) ?? nil).flatMap { $0.nilIfBlank }

        switch kind {
        case .heading:
            let heading = text.isEmpty ? (title ?? "") : text
            guard heading.count >= 2 else { return [] }
            let level = (try? container.decode(Int.self, forKey: .level)) ?? 2
            return [.heading(level: level <= 1 ? 1 : 2, text: heading)]

        case .paragraph:
            guard text.count >= 2 else { return [] }
            // Un pavé se coupe à une fin de phrase, ici comme sur le serveur : c'est une
            // conversion de lecture, au même titre qu'un ancien tableau devenu ses lignes,
            // et les fiches déjà en base en profitent sans qu'on les réécrive.
            return SheetText.split(text).map { .paragraph(text: $0) }

        case .list:
            let items = Self.strings(container, .items)
            guard !items.isEmpty else { return [] }
            let ordered = (try? container.decode(Bool.self, forKey: .ordered)) ?? false
            return [.list(ordered: ordered, items: items)]

        case .formula:
            let raw = (try? container.decode(String.self, forKey: .latex)) ?? text
            let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "$ \n"))
            guard let formula = SheetText.normalizedFormula(trimmed, caption: caption) else { return [] }
            return [.formula(latex: formula.latex, caption: formula.caption)]

        // MARK: Les blocs d'avant, convertis plutôt que jetés

        case .definition:
            let term = ((try? container.decode(String.self, forKey: .term)) ?? title ?? "")
            guard term.count >= 2, text.count >= 2 else { return [] }
            // Le terme passe en gras dans la phrase : c'est exactement ce que la définition
            // encadrée disait, sans le cadre.
            return [.paragraph(text: "**\(term)** : \(text)")]

        case .callout:
            guard text.count >= 2 else { return [] }
            return [.paragraph(text: text)]

        case .steps:
            let items = Self.strings(container, .items)
            guard !items.isEmpty else { return [] }
            return Self.titled(title) + [.list(ordered: true, items: items)]

        case .keypoints:
            let items = Self.pairs(container, .items, valueKey: "value")
            guard !items.isEmpty else { return [] }
            return Self.titled(title) + [.list(ordered: false, items: items)]

        case .qa:
            let items = Self.pairs(container, .items, labelKey: "question", valueKey: "answer")
            guard !items.isEmpty else { return [] }
            return items.map { .paragraph(text: $0) }

        case .table:
            let headers = Self.strings(container, .headers)
            let rows = ((try? container.decode([[SheetScalar]].self, forKey: .rows)) ?? [])
                .map { $0.map(\.text) }
                .filter { row in row.contains { !$0.isEmpty } }
            guard !rows.isEmpty else { return [] }

            // Une ligne devient « colonne : valeur, colonne : valeur ». C'est ce que la mise
            // à plat faisait déjà pour le modèle des cartes ; la fiche le lit maintenant pareil.
            let items = rows.map { row in
                row.enumerated()
                    .filter { !$0.element.isEmpty }
                    .map { entry -> String in
                        let header = headers.indices.contains(entry.offset) ? headers[entry.offset] : ""
                        return header.isEmpty ? entry.element : "**\(header)** : \(entry.element)"
                    }
                    .joined(separator: ", ")
            }
            .filter { !$0.isEmpty }
            .prefix(SheetLimits.listItems)

            var out = Self.titled(title)
            if !items.isEmpty { out.append(.list(ordered: false, items: Array(items))) }
            if let caption { out.append(.paragraph(text: caption)) }
            return out

        case .chart:
            let unit = ((try? container.decodeIfPresent(String.self, forKey: .unit)) ?? nil).flatMap { $0.nilIfBlank }
            let bars = ((try? container.decode([SheetBar].self, forKey: .bars)) ?? [])
                .compactMap { bar -> String? in
                    guard !bar.label.isEmpty, let value = bar.value else { return nil }
                    let number = value == value.rounded() ? String(Int(value)) : String(value)
                    return "**\(bar.label)** : \(number)\(unit.map { " \($0)" } ?? "")"
                }
                .prefix(SheetLimits.listItems)
            guard !bars.isEmpty else { return [] }
            return Self.titled(title) + [.list(ordered: false, items: Array(bars))]

        // Les figures avaient déjà quitté les fiches : une image recadrée d'un scan était
        // décorative et souvent illisible. La légende, elle, disait quelque chose.
        case .figure:
            let legend = caption ?? (text.isEmpty ? (title ?? "") : text)
            guard legend.count >= 4 else { return [] }
            return [.paragraph(text: legend)]

        // Un schéma dessiné par l'application n'a pas d'équivalent en texte : ses nœuds ne
        // sont que des étiquettes, et les mettre en liste inventerait un ordre.
        case .diagram:
            return []
        }
    }

    private static func titled(_ title: String?) -> [SheetBlock] {
        guard let title else { return [] }
        return [.paragraph(text: "**\(title)**")]
    }

    private static func strings(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> [String] {
        ((try? container.decode([SheetScalar].self, forKey: key)) ?? [])
            .map(\.text)
            .filter { !$0.isEmpty }
    }

    /// Les anciennes listes d'objets - chiffres clés, questions - rendues en « label : valeur ».
    private static func pairs(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys,
        labelKey: String = "label",
        valueKey: String
    ) -> [String] {
        ((try? container.decode([[String: SheetScalar]].self, forKey: key)) ?? [])
            .compactMap { entry in
                let label = entry[labelKey]?.text ?? ""
                let value = entry[valueKey]?.text ?? ""
                guard !label.isEmpty, !value.isEmpty else { return nil }
                return "**\(label)** : \(value)"
            }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .heading(let level, let text):
            try container.encode(Kind.heading.rawValue, forKey: .type)
            try container.encode(level, forKey: .level)
            try container.encode(text, forKey: .text)

        case .paragraph(let text):
            try container.encode(Kind.paragraph.rawValue, forKey: .type)
            try container.encode(text, forKey: .text)

        case .list(let ordered, let items):
            try container.encode(Kind.list.rawValue, forKey: .type)
            try container.encode(ordered, forKey: .ordered)
            try container.encode(items, forKey: .items)

        case .formula(let latex, let caption):
            try container.encode(Kind.formula.rawValue, forKey: .type)
            try container.encode(latex, forKey: .latex)
            try container.encodeIfPresent(caption, forKey: .caption)
        }
    }
}

// MARK: - Valeur scalaire tolérante

/// Cellule ou valeur reçue du modèle, qu'elle arrive en chaîne, en nombre ou en booléen.
/// Une liste dont un élément est écrit `12` au lieu de `"12"` ne doit pas disparaître.
struct SheetScalar: Codable, Equatable {
    var text: String

    var number: Double? {
        let normalized = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "%", with: "")
        return Double(normalized)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(String.self) {
            text = value
        } else if let value = try? container.decode(Double.self) {
            text = value == value.rounded() ? String(Int(value)) : String(value)
        } else if let value = try? container.decode(Bool.self) {
            text = value ? "oui" : "non"
        } else {
            text = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

/// Une barre d'un ancien graphe, le temps de la relire une dernière fois.
private struct SheetBar: Decodable {
    let label: String
    let value: Double?

    private enum CodingKeys: String, CodingKey {
        case label, value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = ((try? container.decode(SheetScalar.self, forKey: .label))?.text ?? "")
            .trimmingCharacters(in: .whitespaces)
        value = (try? container.decode(SheetScalar.self, forKey: .value))?.number
    }
}

// MARK: - Garde-fous

/// Ce qu'une fiche ne dépasse pas.
///
/// Les plafonds ont monté avec le format : une fiche est maintenant plus longue et plus
/// neutre, et ce qu'un tableau tenait en quatre colonnes s'écrit désormais en autant de
/// lignes. Ils sont recopiés à l'identique dans `SHEET_LIMITS`, côté serveur et côté site,
/// et un test compare les trois.
enum SheetLimits {
    static let blocks = 90
    static let listItems = 10
    /// Ce qu'on surligne sur une fiche entière. Au-delà, plus rien ne ressort.
    static let highlights = 24
    /// **Ce qu'un paragraphe pèse au plus, en caractères.**
    ///
    /// Un paragraphe de fiche en fait cent cinquante ; la consigne de longueur en faisait
    /// écrire de six cents, parce que le modèle n'a que deux façons d'allonger — des blocs de
    /// plus, ou des phrases de plus — et que la seconde ne coûte rien. Six cents caractères,
    /// c'est treize lignes d'iPhone d'un seul tenant : on ne les relit pas, on les saute.
    ///
    /// Il descend de cinq cents à trois cent vingt, la valeur que le prompt demande, plus une
    /// phrase de marge : cinq cents laissait passer des blocs de onze lignes, et un pavé
    /// coupé en deux pavés n'est toujours pas une fiche.
    ///
    /// Recopié dans `SHEET_LIMITS.paragraphChars` côté serveur, où `splitParagraph` fait le
    /// même découpage. Un test compare les deux.
    static let paragraphChars = 320
    /// **Ce qu'une formule pèse au plus, en caractères.**
    ///
    /// Les formules d'une fiche font entre six et cent trente caractères. Au delà de deux
    /// cent quarante, ce n'est plus une formule : c'est un paragraphe écrit en LaTeX, ou une
    /// boucle du modèle. Recopié dans `FORMULA_MAX_CHARS` côté serveur.
    static let formulaChars = 240
    /// Le chapeau, en mots. Voir `SheetText.lead` : deux lignes de téléphone, pas plus.
    static let summaryWords = 20
}

/// Nettoyage des textes de la fiche.
///
/// À la différence de `TextSanitizer.clean`, qui vaut pour les cartes, on **garde** le
/// balisage en ligne : c'est lui qui porte le gras, l'italique et le surlignage. Ce qui
/// part, ce sont les tirets cadratins, les puces écrites à la main et les dièses de
/// markdown, c'est-à-dire exactement les marques d'un texte laissé tel que l'IA l'a rendu.
enum SheetText {
    static func clean(_ text: String) -> String? {
        var result = TextSanitizer.removeEmDashes(text)
        result = result.replacingOccurrences(of: "\u{00A0}", with: " ")

        // Un bloc porte déjà sa forme : une puce ou un dièse en tête de texte est du
        // markdown qui a fui hors de sa structure.
        while let first = result.first, "-•*#>◦·".contains(first) {
            // `*mot*` en tête de paragraphe est de l'italique, pas une puce.
            if first == "*", result.dropFirst().contains("*") { break }
            result = String(result.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        result = result.replacingOccurrences(of: "\n", with: " ")
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    /// **Rend son antislash à une commande LaTeX déjà enregistrée.**
    ///
    /// Le mal est réparé à la lecture du modèle, côté serveur, mais les fiches écrites avant
    /// portent la cicatrice : `\rightarrow` mal échappé est une échappée JSON **valide**,
    /// donc `2H_2O\rightarrow4H^+` a été enregistré comme un retour chariot suivi de
    /// « ightarrow ». Rien ne le signale, et l'équation s'affiche amputée de sa flèche.
    ///
    /// Un caractère de contrôle collé à une lettre n'a aucun sens dans une formule : il n'y a
    /// donc rien à deviner. Les cinq concernés sont exactement les cinq échappées JSON d'une
    /// seule lettre qui commencent aussi des commandes courantes.
    ///
    /// Jumeau de `restoreLatexCommands` dans `supabase/functions/_shared/sheet.ts`.
    static func restoringLatexCommands(_ latex: String) -> String {
        let commands: [Character: Character] = [
            "\u{08}": "b",
            "\u{0C}": "f",
            "\n": "n",
            "\r": "r",
            "\t": "t"
        ]
        let characters = Array(latex)
        var out = ""
        for (index, character) in characters.enumerated() {
            let followed = index + 1 < characters.count
                && characters[index + 1].isASCII
                && characters[index + 1].isLetter
            if let command = commands[character], followed {
                out.append("\\")
                out.append(command)
            } else {
                out.append(character)
            }
        }
        return out
    }

    /// **Une formule répétée est une boucle, pas une formule.**
    ///
    /// Relevé tel quel : l'équation de la photosynthèse écrite quatorze fois de suite dans
    /// un seul bloc, sans séparateur. Un modèle qui se répète le fait jusqu'à sa limite de
    /// jetons, et le rendu en fait un pavé de mille caractères là où une ligne suffisait.
    ///
    /// **Un motif long, répété au moins trois fois.** Les deux bornes existent pour la même
    /// raison : `x + x + x + x` est une somme, pas une boucle. La dernière répétition a le
    /// droit d'être tronquée, puisque c'est la limite de jetons qui a arrêté le modèle.
    ///
    /// Jumeau de `collapseRepeatedFormula` dans `supabase/functions/_shared/sheet.ts`.
    static func collapsingRepeatedFormula(_ latex: String) -> String {
        let text = latex.trimmingCharacters(in: .whitespaces)
        let characters = Array(text)
        guard characters.count >= 60 else { return text }

        var unit = 20
        while unit <= characters.count / 3 {
            let head = Array(characters[0..<unit])
            var repeated = true
            var at = unit
            while at < characters.count {
                let chunk = Array(characters[at..<min(at + unit, characters.count)])
                if !head.starts(with: chunk) {
                    repeated = false
                    break
                }
                at += unit
            }
            if repeated { return String(head) }
            unit += 1
        }
        return text
    }

    /// **La formule, ramenée à ce que l'application sait composer.**
    ///
    /// `\xrightarrow{Lumière}` est de l'amsmath ; le moteur ne l'analyse pas, la composition
    /// échoue, et le repli en Unicode affichait « xrightarrowLumière » en toutes lettres au
    /// milieu de l'équation. La flèche redevient une flèche ordinaire, que le moteur compose,
    /// et **l'étiquette part dans la légende** plutôt qu'à la poubelle.
    ///
    /// Rend `nil` quand il ne reste rien de composable, ou quand la formule dépasse le
    /// plafond : un bloc absent se remarque moins qu'un mur de LaTeX.
    ///
    /// Jumeau de `normalizeFormula` côté serveur.
    static func normalizedFormula(_ latex: String, caption: String?) -> (latex: String, caption: String?)? {
        var labels: [String] = []
        var source = collapsingRepeatedFormula(restoringLatexCommands(latex))

        if let arrows = try? NSRegularExpression(
            pattern: "\\\\x(right|left)arrow\\s*(?:\\[[^\\]]*\\])?\\s*\\{([^{}]*)\\}"
        ) {
            let full = NSRange(source.startIndex..., in: source)
            var out = ""
            var cursor = source.startIndex
            for match in arrows.matches(in: source, range: full) {
                guard let whole = Range(match.range, in: source),
                      let sideRange = Range(match.range(at: 1), in: source),
                      let labelRange = Range(match.range(at: 2), in: source)
                else { continue }
                out += source[cursor..<whole.lowerBound]
                out += source[sideRange] == "right" ? "\\rightarrow" : "\\leftarrow"
                let clean = source[labelRange].trimmingCharacters(in: .whitespaces)
                if !clean.isEmpty { labels.append(clean) }
                cursor = whole.upperBound
            }
            out += source[cursor...]
            source = out
        }

        source = source.trimmingCharacters(in: .whitespaces)
        guard source.count >= 2, source.count <= SheetLimits.formulaChars else { return nil }

        let parts = ([caption?.trimmingCharacters(in: .whitespaces)].compactMap { $0 } + labels)
            .filter { !$0.isEmpty }
        return (source, parts.isEmpty ? nil : parts.joined(separator: " · "))
    }

    /// **Un paragraphe trop long, coupé à une fin de phrase.**
    ///
    /// C'est un filet, pas une réécriture : pas un mot changé, rien de résumé, rien de
    /// recomposé. On relève les fins de phrase et on empile les phrases jusqu'au plafond.
    /// Deux paragraphes de prose valide valent mieux qu'un pavé de treize lignes, et
    /// l'étudiant peut les recoller d'une touche — l'inverse lui demandait de retrouver à
    /// l'œil où la phrase s'arrête.
    ///
    /// **On ne coupe jamais au milieu d'une phrase.** Une phrase plus longue que le plafond
    /// à elle seule sort telle quelle : tranchée en deux blocs, elle se lirait comme un bug
    /// d'affichage, et le remède serait pire que le mal.
    ///
    /// Jumeau de `splitParagraph` dans `supabase/functions/_shared/sheet.ts`.
    static func split(_ text: String, limit: Int = SheetLimits.paragraphChars) -> [String] {
        guard text.count > limit else { return [text] }
        let flat = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard flat.count > limit else { return [text] }

        let pieces = sentences(of: flat)
        guard pieces.count > 1 else { return [text] }

        var parts: [String] = []
        var current = ""
        for piece in pieces {
            let merged = current.isEmpty ? piece : current + " " + piece
            if !current.isEmpty, merged.count > limit {
                parts.append(current)
                current = piece
            } else {
                current = merged
            }
        }
        if !current.isEmpty { parts.append(current) }

        // Une queue d'une demi-ligne se lit comme une coupure ratée, pas comme un paragraphe.
        // Elle repart avec celui qui la précède, quitte à lui faire dépasser le plafond.
        if parts.count > 1, let last = parts.last, last.count < 60 {
            parts.removeLast()
            parts[parts.count - 1] = parts[parts.count - 1] + " " + last
        }

        return parts.isEmpty ? [text] : parts
    }

    /// Les phrases d'un texte, relevées hors des formules et hors des marques.
    private static func sentences(of text: String) -> [String] {
        let characters = Array(text)
        let spans = protectedSpans(characters)
        var out: [String] = []
        var start = 0
        var index = 0

        while index < characters.count {
            defer { index += 1 }
            guard ".!?…".contains(characters[index]) else { continue }
            if spans.contains(where: { index >= $0.lowerBound && index < $0.upperBound }) { continue }

            // Une initiale n'est pas une fin de phrase : « M. Dupont », « J. Monod ».
            if index >= 2, characters[index - 1].isUppercase, characters[index - 2].isWhitespace {
                continue
            }

            var after = index + 1
            while after < characters.count, characters[after].isWhitespace { after += 1 }
            guard after > index + 1, after < characters.count else { continue }

            // Ce qui ouvre la phrase suivante : une capitale, un chiffre, un guillemet, ou
            // le marqueur d'un terme en gras — « **La réplication** … » ouvre sur une étoile.
            let opener = characters[after]
            guard opener.isUppercase || opener.isNumber || "*=$«\"([".contains(opener) else { continue }

            let sentence = String(characters[start...index]).trimmingCharacters(in: .whitespaces)
            // Trop court pour être une phrase : c'est une abréviation prise pour un point.
            guard sentence.count >= 40 else { continue }

            out.append(sentence)
            start = after
        }

        let rest = String(characters[start...]).trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { out.append(rest) }
        return out
    }

    /// Les portions qu'une coupure ne doit pas traverser : les formules et les marques.
    ///
    /// Un point dans `$3.14$` n'est pas une fin de phrase, et une coupure au milieu d'un
    /// `**terme**` laisserait deux étoiles orphelines dans chaque moitié.
    private static func protectedSpans(_ characters: [Character]) -> [Range<Int>] {
        var spans: [Range<Int>] = []
        for marker in ["$", "**", "=="] {
            let glyphs = Array(marker)
            var index = 0
            while index < characters.count {
                guard let open = position(of: glyphs, in: characters, from: index),
                      let close = position(of: glyphs, in: characters, from: open + glyphs.count)
                else { break }
                spans.append(open..<(close + glyphs.count))
                index = close + glyphs.count
            }
        }
        return spans
    }

    private static func position(of glyphs: [Character], in characters: [Character], from: Int) -> Int? {
        guard !glyphs.isEmpty, from >= 0 else { return nil }
        var index = from
        while index + glyphs.count <= characters.count {
            if Array(characters[index..<(index + glyphs.count)]) == glyphs { return index }
            index += 1
        }
        return nil
    }

    /// **Le chapeau d'une fiche : vingt mots, jamais plus.**
    ///
    /// Il se lit entre le titre et la première partie, composé plus grand que le corps du
    /// texte. À cette taille, deux phrases pleines occupent le haut de l'écran et repoussent
    /// la fiche sous la ligne de flottaison : on ouvre un cours et on lit d'abord un résumé
    /// du cours. Or ce n'est pas ce qu'on vient chercher — le chapeau sert à reconnaître la
    /// fiche, pas à la remplacer.
    ///
    /// La coupe est faite **ici, à l'affichage**, et pas seulement à la génération. Le
    /// serveur borne ce qu'il écrit désormais, mais toutes les fiches déjà en base portent
    /// leurs deux phrases, et personne ne va les réécrire.
    ///
    /// **Elle respecte les phrases.** On garde les phrases entières tant qu'elles tiennent
    /// dans le compte ; une phrase coupée en son milieu se lit comme une panne. Quand pas une
    /// seule ne tient — le modèle en écrit parfois une, plus longue que la limite — on coupe
    /// au vingtième mot et on pose des points de suspension.
    ///
    /// Jumeau de `clampSummary` dans `supabase/functions/_shared/sheet.ts`.
    static func lead(_ text: String, limit: Int = SheetLimits.summaryWords) -> String {
        let clean = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        if clean.isEmpty { return "" }

        let words = clean.split(separator: " ")
        if words.count <= limit { return clean }

        var kept = ""
        var count = 0
        var current = ""

        for character in clean {
            current.append(character)
            guard ".!?…".contains(character) else { continue }
            // Une fin de phrase : on sait enfin combien de mots elle pesait.
            let size = current.split(whereSeparator: \.isWhitespace).count
            if count + size > limit { break }
            kept += current
            count += size
            current = ""
        }

        let trimmed = kept.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }

        // Pas une seule phrase ne tient : on coupe au mot, sans ponctuation pendante.
        // « …des actes, … » se lit comme une panne d'affichage.
        var cut = words.prefix(limit).joined(separator: " ")
        while let last = cut.last, " ,;:.!?…".contains(last) { cut.removeLast() }
        return cut + "…"
    }
}
