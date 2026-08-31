import Foundation

/// La fiche d'un cours : ce que Micabo écrit à partir du document importé.
///
/// Un import ne produit plus seulement des cartes. Il produit d'abord une **fiche**, qui
/// est ce que l'étudiant lit, et à partir de laquelle il peut, s'il le veut, demander des
/// cartes. La fiche est donc du contenu de plein droit : elle est mise en page, elle porte
/// du gras, de l'italique et du surlignage, et elle a droit à un tableau, à un graphe ou à
/// une formule quand le cours s'y prête.
///
/// Les huit blocs ci-dessous sont volontairement peu nombreux. Chacun a un rendu dessiné
/// pour lui, ce qui est la seule façon de tenir une belle page : un format ouvert, où le
/// modèle inventerait ses propres structures, donnerait une page différente à chaque cours.
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
    private struct LenientBlock: Decodable {
        let block: SheetBlock?

        init(from decoder: Decoder) throws {
            block = try? SheetBlock(from: decoder)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lenient = try container.decode([LenientBlock].self, forKey: .blocks)
        blocks = lenient.compactMap(\.block)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(blocks, forKey: .blocks)
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
    /// Un terme et sa définition.
    case definition(term: String, text: String)
    /// Encadré : l'essentiel, un piège, un exemple, une astuce.
    case callout(tone: SheetCalloutTone, text: String)
    /// Étapes ordonnées d'un mécanisme ou d'une méthode.
    case steps(title: String?, items: [String])
    /// Tableau de comparaison.
    case table(SheetTable)
    /// Graphe en barres, quand le document porte des valeurs qui se comparent.
    case chart(SheetChart)
    /// Formule mise en valeur, avec la légende de ses symboles.
    case formula(latex: String, caption: String?)

    // MARK: Texte brut

    func plainLines() -> [String] {
        switch self {
        case .heading(_, let text):
            return [SheetMarkup.plain(text)].filter { !$0.isEmpty }

        case .paragraph(let text):
            return [SheetMarkup.plain(text)].filter { !$0.isEmpty }

        case .definition(let term, let text):
            return ["\(SheetMarkup.plain(term)) : \(SheetMarkup.plain(text))"]

        case .callout(_, let text):
            return [SheetMarkup.plain(text)].filter { !$0.isEmpty }

        case .steps(let title, let items):
            let lines = items.enumerated().map { "\($0.offset + 1). \(SheetMarkup.plain($0.element))" }
            guard let title = title?.nilIfBlank else { return lines }
            return [SheetMarkup.plain(title)] + lines

        case .table(let table):
            return table.plainLines()

        case .chart(let chart):
            return chart.plainLines()

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
            guard let clean = SheetText.clean(text) else { return nil }
            return .paragraph(text: clean)

        case .definition(let term, let text):
            guard let cleanTerm = SheetText.clean(term), let clean = SheetText.clean(text) else { return nil }
            return .definition(term: cleanTerm, text: clean)

        case .callout(let tone, let text):
            guard let clean = SheetText.clean(text) else { return nil }
            return .callout(tone: tone, text: clean)

        case .steps(let title, let items):
            let clean = items.compactMap(SheetText.clean)
            guard clean.count >= 2 else { return nil }
            return .steps(
                title: title.flatMap(SheetText.clean),
                items: Array(clean.prefix(SheetLimits.stepsPerBlock))
            )

        case .table(let table):
            guard let clean = table.sanitized() else { return nil }
            return .table(clean)

        case .chart(let chart):
            guard let clean = chart.sanitized() else { return nil }
            return .chart(clean)

        case .formula(let latex, let caption):
            guard let clean = latex.nilIfBlank else { return nil }
            return .formula(latex: clean, caption: caption.flatMap(SheetText.clean))
        }
    }

    // MARK: Codage

    private enum CodingKeys: String, CodingKey {
        case type, level, text, term, title, items, caption, latex, tone, headers, rows, bars, unit
    }

    /// Nom du bloc sur le fil : c'est aussi le vocabulaire du prompt côté serveur.
    private enum Kind: String {
        case heading, paragraph, definition, callout, steps, table, chart, formula
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = (try? container.decode(String.self, forKey: .type))?
            .trimmingCharacters(in: .whitespaces)
            .lowercased() ?? ""

        guard let kind = Kind(rawValue: rawType) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Bloc de fiche « \(rawType) » inconnu."
                )
            )
        }

        let title = try? container.decodeIfPresent(String.self, forKey: .title)
        let text = (try? container.decode(String.self, forKey: .text)) ?? ""

        switch kind {
        case .heading:
            let level = (try? container.decode(Int.self, forKey: .level)) ?? 2
            self = .heading(level: level <= 1 ? 1 : 2, text: text.isEmpty ? (title ?? "") : text)

        case .paragraph:
            self = .paragraph(text: text)

        case .definition:
            let term = (try? container.decode(String.self, forKey: .term)) ?? title ?? ""
            self = .definition(term: term, text: text)

        case .callout:
            let tone = (try? container.decode(SheetCalloutTone.self, forKey: .tone)) ?? .essentiel
            self = .callout(tone: tone, text: text)

        case .steps:
            let items = (try? container.decode([SheetScalar].self, forKey: .items))?.map(\.text) ?? []
            self = .steps(title: title, items: items)

        case .table:
            self = .table(
                SheetTable(
                    title: title,
                    headers: (try? container.decode([SheetScalar].self, forKey: .headers))?.map(\.text) ?? [],
                    rows: (try? container.decode([[SheetScalar]].self, forKey: .rows))?.map { $0.map(\.text) } ?? [],
                    caption: try? container.decodeIfPresent(String.self, forKey: .caption)
                )
            )

        case .chart:
            self = .chart(
                SheetChart(
                    title: title,
                    bars: (try? container.decode([SheetChart.Bar].self, forKey: .bars)) ?? [],
                    unit: try? container.decodeIfPresent(String.self, forKey: .unit),
                    caption: try? container.decodeIfPresent(String.self, forKey: .caption)
                )
            )

        case .formula:
            let latex = (try? container.decode(String.self, forKey: .latex)) ?? text
            self = .formula(latex: latex, caption: try? container.decodeIfPresent(String.self, forKey: .caption))
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

        case .definition(let term, let text):
            try container.encode(Kind.definition.rawValue, forKey: .type)
            try container.encode(term, forKey: .term)
            try container.encode(text, forKey: .text)

        case .callout(let tone, let text):
            try container.encode(Kind.callout.rawValue, forKey: .type)
            try container.encode(tone, forKey: .tone)
            try container.encode(text, forKey: .text)

        case .steps(let title, let items):
            try container.encode(Kind.steps.rawValue, forKey: .type)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encode(items, forKey: .items)

        case .table(let table):
            try container.encode(Kind.table.rawValue, forKey: .type)
            try container.encodeIfPresent(table.title, forKey: .title)
            try container.encode(table.headers, forKey: .headers)
            try container.encode(table.rows, forKey: .rows)
            try container.encodeIfPresent(table.caption, forKey: .caption)

        case .chart(let chart):
            try container.encode(Kind.chart.rawValue, forKey: .type)
            try container.encodeIfPresent(chart.title, forKey: .title)
            try container.encode(chart.bars, forKey: .bars)
            try container.encodeIfPresent(chart.unit, forKey: .unit)
            try container.encodeIfPresent(chart.caption, forKey: .caption)

        case .formula(let latex, let caption):
            try container.encode(Kind.formula.rawValue, forKey: .type)
            try container.encode(latex, forKey: .latex)
            try container.encodeIfPresent(caption, forKey: .caption)
        }
    }
}

/// Ce qu'un encadré vient dire. Quatre intentions, pas plus : au delà, la page devient un
/// nuancier et l'étudiant ne sait plus ce qui compte.
enum SheetCalloutTone: String, Codable, Equatable, CaseIterable, Sendable {
    /// Ce qu'il faut retenir du passage.
    case essentiel
    /// Le piège classique, la confusion fréquente.
    case attention
    /// Un exemple concret.
    case exemple
    /// Une méthode, un moyen de retenir.
    case astuce

    /// Intitulé posé au-dessus de l'encadré.
    var label: String {
        switch self {
        case .essentiel: "À retenir"
        case .attention: "Attention"
        case .exemple: "Exemple"
        case .astuce: "Astuce"
        }
    }

    var systemImage: String {
        switch self {
        case .essentiel: "star.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .exemple: "text.quote"
        case .astuce: "lightbulb.fill"
        }
    }

    /// Le modèle écrit parfois « piège » ou « warning » : on retombe sur l'intention la
    /// plus proche plutôt que de perdre l'encadré.
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self))?
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces) ?? ""

        switch raw {
        case "attention", "piege", "warning", "danger": self = .attention
        case "exemple", "example": self = .exemple
        case "astuce", "methode", "tip", "conseil": self = .astuce
        default: self = .essentiel
        }
    }
}

// MARK: - Tableau

/// Tableau de la fiche. Deux à quatre colonnes : au delà, rien ne se lit sur un téléphone.
struct SheetTable: Equatable, Sendable {
    var title: String?
    var headers: [String]
    var rows: [[String]]
    var caption: String?

    init(title: String? = nil, headers: [String], rows: [[String]], caption: String? = nil) {
        self.title = title
        self.headers = headers
        self.rows = rows
        self.caption = caption
    }

    var columnCount: Int {
        headers.count
    }

    func plainLines() -> [String] {
        var lines: [String] = []
        if let title = title?.nilIfBlank { lines.append(SheetMarkup.plain(title)) }
        for row in rows {
            let cells = zip(headers, row)
                .filter { !$0.1.isEmpty }
                .map { header, value -> String in
                    // Un tableau de comparaison a souvent une première colonne sans
                    // intitulé : la cellule vaut alors pour elle-même.
                    let name = SheetMarkup.plain(header)
                    let content = SheetMarkup.plain(value)
                    return name.isEmpty ? content : "\(name) : \(content)"
                }
            guard !cells.isEmpty else { continue }
            lines.append(cells.joined(separator: ", "))
        }
        if let caption = caption?.nilIfBlank { lines.append(SheetMarkup.plain(caption)) }
        return lines
    }

    /// Une ligne qui n'a pas le bon nombre de cellules est complétée plutôt que jetée :
    /// le contenu des cellules présentes reste juste.
    func sanitized() -> SheetTable? {
        let cleanHeaders = headers.map { SheetText.clean($0) ?? "" }
        guard cleanHeaders.count >= 2 else { return nil }
        let columns = min(cleanHeaders.count, SheetLimits.tableColumns)

        let cleanRows: [[String]] = rows.compactMap { row in
            let cells = row.map { SheetText.clean($0) ?? "" }
            guard cells.contains(where: { !$0.isEmpty }) else { return nil }
            return cells.count >= columns
                ? Array(cells.prefix(columns))
                : cells + Array(repeating: "", count: columns - cells.count)
        }

        guard cleanRows.count >= 2 else { return nil }

        return SheetTable(
            title: title.flatMap(SheetText.clean),
            headers: Array(cleanHeaders.prefix(columns)),
            rows: Array(cleanRows.prefix(SheetLimits.tableRows)),
            caption: caption.flatMap(SheetText.clean)
        )
    }
}

// MARK: - Graphe

/// Graphe en barres : le seul graphe de la fiche.
///
/// Micabo n'essaie pas de reproduire les figures du document, ce serait toujours moins bon
/// que l'original. Il ne dessine que ce qui se compare : des valeurs nommées, dans la même
/// unité, mises côte à côte.
struct SheetChart: Equatable, Sendable {
    struct Bar: Codable, Equatable, Sendable {
        var label: String
        var value: Double

        init(label: String, value: Double) {
            self.label = label
            self.value = value
        }

        private enum CodingKeys: String, CodingKey {
            case label, value
        }

        /// Une valeur peut arriver en nombre ou en chaîne (« 40 », « 40 % ») : les deux
        /// sont acceptées, sinon la barre serait perdue pour un guillemet.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            label = (try? container.decode(String.self, forKey: .label)) ?? ""
            value = (try container.decode(SheetScalar.self, forKey: .value)).number ?? 0
        }
    }

    var title: String?
    var bars: [Bar]
    var unit: String?
    var caption: String?

    init(title: String? = nil, bars: [Bar], unit: String? = nil, caption: String? = nil) {
        self.title = title
        self.bars = bars
        self.unit = unit
        self.caption = caption
    }

    var maximum: Double {
        max(bars.map(\.value).max() ?? 1, 0.0001)
    }

    /// Valeur écrite au bout de la barre. Un entier reste un entier, et le pourcentage
    /// reste collé à son nombre.
    func formatted(_ value: Double) -> String {
        let number = value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
        guard let unit = unit?.nilIfBlank else { return number }
        return unit == "%" ? number + unit : number + " " + unit
    }

    func plainLines() -> [String] {
        var lines: [String] = []
        if let title = title?.nilIfBlank { lines.append(SheetMarkup.plain(title)) }
        lines.append(
            bars
                .map { "\(SheetMarkup.plain($0.label)) : \(formatted($0.value))" }
                .joined(separator: ", ")
        )
        if let caption = caption?.nilIfBlank { lines.append(SheetMarkup.plain(caption)) }
        return lines
    }

    /// Une seule barre ne compare rien, et une valeur négative ne se dessine pas dans ce
    /// graphe : dans les deux cas le bloc disparaît.
    func sanitized() -> SheetChart? {
        let cleanBars = bars.compactMap { bar -> Bar? in
            guard let label = SheetText.clean(bar.label), bar.value >= 0, bar.value.isFinite else { return nil }
            return Bar(label: label, value: bar.value)
        }
        guard cleanBars.count >= 2, cleanBars.contains(where: { $0.value > 0 }) else { return nil }

        return SheetChart(
            title: title.flatMap(SheetText.clean),
            bars: Array(cleanBars.prefix(SheetLimits.chartBars)),
            unit: unit.flatMap(SheetText.clean),
            caption: caption.flatMap(SheetText.clean)
        )
    }
}

// MARK: - Valeur scalaire tolérante

/// Cellule ou valeur reçue du modèle, qu'elle arrive en chaîne, en nombre ou en booléen.
/// Un tableau dont une case est écrite `12` au lieu de `"12"` ne doit pas disparaître.
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

// MARK: - Garde-fous

/// Ce qu'une fiche ne dépasse pas. Ces plafonds ne sont pas décoratifs : une fiche de
/// quatre-vingts blocs, ou un tableau de six colonnes, ne se lit plus sur un téléphone.
enum SheetLimits {
    static let blocks = 60
    static let stepsPerBlock = 7
    static let tableColumns = 4
    static let tableRows = 8
    static let chartBars = 6
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
