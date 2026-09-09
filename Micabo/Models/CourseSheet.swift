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
/// Le code couleur d'une fiche n'appartient qu'à celui qui la relit : le modèle marque en
/// jaune ce qui compte, et l'étudiant recolore. Cinq teintes, pas plus - au delà, une page
/// surlignée devient un nuancier et plus rien n'y ressort.
enum SheetHighlight: String, Codable, Equatable, CaseIterable, Sendable {
    case jaune
    case menthe
    case bleu
    case rose
    case lilas

    /// Ce que vaut un `==texte==` sans couleur écrite.
    static let fallback: SheetHighlight = .jaune
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
            return [.paragraph(text: text)]

        case .list:
            let items = Self.strings(container, .items)
            guard !items.isEmpty else { return [] }
            let ordered = (try? container.decode(Bool.self, forKey: .ordered)) ?? false
            return [.list(ordered: ordered, items: items)]

        case .formula:
            let raw = (try? container.decode(String.self, forKey: .latex)) ?? text
            let latex = raw.trimmingCharacters(in: CharacterSet(charactersIn: "$ \n"))
            guard latex.count >= 2 else { return [] }
            return [.formula(latex: latex, caption: caption)]

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
}
