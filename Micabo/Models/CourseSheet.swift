import Foundation
import UIKit

/// La fiche d'un cours : ce que Micabo écrit à partir du document importé.
///
/// Un import ne produit plus seulement des cartes. Il produit d'abord une **fiche**, qui
/// est ce que l'étudiant lit, et à partir de laquelle il peut, s'il le veut, demander des
/// cartes. La fiche est donc du contenu de plein droit : elle est mise en page, elle porte
/// du gras, de l'italique et du surlignage, et elle a droit à un tableau, à un graphe ou à
/// une formule quand le cours s'y prête.
///
/// Les douze blocs ci-dessous sont **fermés** : chacun a un rendu dessiné pour lui, ce qui
/// est la seule façon de tenir une belle page. Un format ouvert, où le modèle inventerait ses
/// propres structures, donnerait une page différente à chaque cours.
///
/// Ils étaient huit, et la fiche s'en trouvait maigre. Il y manquait précisément ce qu'on
/// dessine à la main sur une fiche papier : une énumération à puces, un schéma, un chiffre
/// posé en grand, une question dont on cache la réponse. Ces quatre-là sont arrivés ensemble,
/// et le graphe a gagné ses formes — une évolution ne se lit pas en barres.
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
    /// Énumération à puces, posée à même la page.
    ///
    /// Elle a longtemps été **interdite**, et pour une bonne raison : une fiche entièrement
    /// à puces est le premier réflexe d'un modèle, et ça donne un plan de diapositives, pas
    /// un cours. Mais l'interdiction totale coûtait plus qu'elle ne rapportait : le modèle
    /// n'avait alors que `steps`, qui numérote, pour rendre trois causes qui n'ont aucun
    /// ordre entre elles, ou un tableau d'une seule colonne pour rendre une liste.
    case list(items: [String])
    /// Un terme et sa définition.
    case definition(term: String, text: String)
    /// Encadré : l'essentiel, un piège, un exemple, une astuce.
    case callout(tone: SheetCalloutTone, text: String)
    /// Étapes ordonnées d'un mécanisme ou d'une méthode.
    case steps(title: String?, items: [String])
    /// Les valeurs qu'il faut connaître par cœur, posées en grand.
    ///
    /// Un seuil, une température, une date : ce sont les choses qu'un correcteur attend au
    /// mot, et elles se perdaient au milieu d'un paragraphe. Ce bloc ne les explique pas, il
    /// les affiche — l'explication est dans le texte qui l'amène.
    case keypoints(title: String?, items: [SheetKeypoint])
    /// De quoi se tester sur place, sans quitter la fiche.
    case quiz(items: [SheetQuestion])
    /// Tableau de comparaison.
    case table(SheetTable)
    /// Schéma dessiné par l'application : une suite, un cycle, une classification, une frise.
    case diagram(SheetDiagram)
    /// Graphe, quand le document porte des valeurs qui se comparent.
    case chart(SheetChart)
    /// Formule mise en valeur, avec la légende de ses symboles.
    case formula(latex: String, caption: String?)
    /// Schéma recadré depuis une page du document, avec sa légende.
    case figure(SheetFigure)

    // MARK: Texte brut

    func plainLines() -> [String] {
        switch self {
        case .heading(_, let text):
            return [SheetMarkup.plain(text)].filter { !$0.isEmpty }

        case .paragraph(let text):
            return [SheetMarkup.plain(text)].filter { !$0.isEmpty }

        case .list(let items):
            return items.map(SheetMarkup.plain).filter { !$0.isEmpty }

        case .definition(let term, let text):
            return ["\(SheetMarkup.plain(term)) : \(SheetMarkup.plain(text))"]

        case .callout(_, let text):
            return [SheetMarkup.plain(text)].filter { !$0.isEmpty }

        case .steps(let title, let items):
            let lines = items.enumerated().map { "\($0.offset + 1). \(SheetMarkup.plain($0.element))" }
            guard let title = title?.nilIfBlank else { return lines }
            return [SheetMarkup.plain(title)] + lines

        case .keypoints(let title, let items):
            // La valeur est collée à ce qu'elle mesure : « 37 » seul ne se révise pas.
            let lines = items.map { "\(SheetMarkup.plain($0.label)) : \(SheetMarkup.plain($0.value))" }
            guard let title = title?.nilIfBlank else { return lines }
            return [SheetMarkup.plain(title)] + lines

        case .quiz(let items):
            return items.map { "\(SheetMarkup.plain($0.question)) \(SheetMarkup.plain($0.answer))" }

        case .table(let table):
            return table.plainLines()

        case .diagram(let diagram):
            return diagram.plainLines()

        case .chart(let chart):
            return chart.plainLines()

        case .formula(let latex, let caption):
            let formula = FormulaRenderer.plain(latex)
            guard let caption = caption?.nilIfBlank else { return [formula] }
            return ["\(formula) (\(SheetMarkup.plain(caption)))"]

        case .figure(let figure):
            return [SheetMarkup.plain(figure.caption)].filter { !$0.isEmpty }
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

        case .list(let items):
            let clean = items.compactMap(SheetText.clean)
            // Une puce seule n'énumère rien : c'est un paragraphe qui a mal tourné.
            guard clean.count >= 2 else { return nil }
            return .list(items: Array(clean.prefix(SheetLimits.listItems)))

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

        case .keypoints(let title, let items):
            let clean = items.compactMap { $0.sanitized() }
            // Un chiffre clé tout seul n'est pas une série de chiffres clés : il est mieux
            // dans la phrase qui l'explique.
            guard clean.count >= 2 else { return nil }
            return .keypoints(
                title: title.flatMap(SheetText.clean),
                items: Array(clean.prefix(SheetLimits.keypoints))
            )

        case .quiz(let items):
            let clean = items.compactMap { $0.sanitized() }
            guard !clean.isEmpty else { return nil }
            return .quiz(items: Array(clean.prefix(SheetLimits.quizItems)))

        case .table(let table):
            guard let clean = table.sanitized() else { return nil }
            return .table(clean)

        case .diagram(let diagram):
            guard let clean = diagram.sanitized() else { return nil }
            return .diagram(clean)

        case .chart(let chart):
            guard let clean = chart.sanitized() else { return nil }
            return .chart(clean)

        case .formula(let latex, let caption):
            guard let clean = latex.nilIfBlank else { return nil }
            return .formula(latex: clean, caption: caption.flatMap(SheetText.clean))

        case .figure(let figure):
            return figure.sanitized().map(SheetBlock.figure)
        }
    }

    // MARK: Codage

    private enum CodingKeys: String, CodingKey {
        case type, level, text, term, title, items, caption, latex, tone, headers, rows, bars, unit
        case kind, layout, nodes, page, crop, image
    }

    /// Nom du bloc sur le fil : c'est aussi le vocabulaire du prompt côté serveur.
    ///
    /// `qa` et non `quiz` : c'est le mot que le prompt emploie, et un nom de bloc se choisit
    /// pour ce que le modèle écrira, pas pour ce que Swift lit le mieux.
    private enum Kind: String {
        case heading, paragraph, list, definition, callout, steps, keypoints, qa, table, diagram, chart, formula, figure
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

        case .list:
            self = .list(items: (try? container.decode([SheetScalar].self, forKey: .items))?.map(\.text) ?? [])

        case .definition:
            let term = (try? container.decode(String.self, forKey: .term)) ?? title ?? ""
            self = .definition(term: term, text: text)

        case .callout:
            let tone = (try? container.decode(SheetCalloutTone.self, forKey: .tone)) ?? .essentiel
            self = .callout(tone: tone, text: text)

        case .steps:
            let items = (try? container.decode([SheetScalar].self, forKey: .items))?.map(\.text) ?? []
            self = .steps(title: title, items: items)

        case .keypoints:
            self = .keypoints(
                title: title,
                items: (try? container.decode([SheetKeypoint].self, forKey: .items)) ?? []
            )

        case .qa:
            self = .quiz(items: (try? container.decode([SheetQuestion].self, forKey: .items)) ?? [])

        case .table:
            self = .table(
                SheetTable(
                    title: title,
                    headers: (try? container.decode([SheetScalar].self, forKey: .headers))?.map(\.text) ?? [],
                    rows: (try? container.decode([[SheetScalar]].self, forKey: .rows))?.map { $0.map(\.text) } ?? [],
                    caption: try? container.decodeIfPresent(String.self, forKey: .caption)
                )
            )

        case .diagram:
            self = .diagram(
                SheetDiagram(
                    layout: (try? container.decode(SheetDiagram.Layout.self, forKey: .layout)) ?? .flow,
                    title: title,
                    nodes: (try? container.decode([SheetDiagram.Node].self, forKey: .nodes)) ?? [],
                    caption: try? container.decodeIfPresent(String.self, forKey: .caption)
                )
            )

        case .chart:
            self = .chart(
                SheetChart(
                    kind: (try? container.decode(SheetChart.Kind.self, forKey: .kind)) ?? .bars,
                    title: title,
                    bars: (try? container.decode([SheetChart.Bar].self, forKey: .bars)) ?? [],
                    unit: try? container.decodeIfPresent(String.self, forKey: .unit),
                    caption: try? container.decodeIfPresent(String.self, forKey: .caption)
                )
            )

        case .formula:
            let latex = (try? container.decode(String.self, forKey: .latex)) ?? text
            self = .formula(latex: latex, caption: try? container.decodeIfPresent(String.self, forKey: .caption))

        case .figure:
            self = .figure(
                SheetFigure(
                    caption: (try? container.decodeIfPresent(String.self, forKey: .caption)) ?? text,
                    page: Self.decodePage(container),
                    crop: try? container.decodeIfPresent(SheetCrop.self, forKey: .crop),
                    imageData: SheetFigureImage.decode(try? container.decodeIfPresent(String.self, forKey: .image))
                )
            )
        }
    }

    private static func decodePage(_ container: KeyedDecodingContainer<CodingKeys>) -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: .page) { return value }
        if let value = try? container.decodeIfPresent(Double.self, forKey: .page) { return Int(value.rounded()) }
        if let value = try? container.decodeIfPresent(String.self, forKey: .page) {
            return Int(value.trimmingCharacters(in: .whitespaces))
        }
        return nil
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

        case .list(let items):
            try container.encode(Kind.list.rawValue, forKey: .type)
            try container.encode(items, forKey: .items)

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

        case .keypoints(let title, let items):
            try container.encode(Kind.keypoints.rawValue, forKey: .type)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encode(items, forKey: .items)

        case .quiz(let items):
            try container.encode(Kind.qa.rawValue, forKey: .type)
            try container.encode(items, forKey: .items)

        case .table(let table):
            try container.encode(Kind.table.rawValue, forKey: .type)
            try container.encodeIfPresent(table.title, forKey: .title)
            try container.encode(table.headers, forKey: .headers)
            try container.encode(table.rows, forKey: .rows)
            try container.encodeIfPresent(table.caption, forKey: .caption)

        case .diagram(let diagram):
            try container.encode(Kind.diagram.rawValue, forKey: .type)
            try container.encode(diagram.layout, forKey: .layout)
            try container.encodeIfPresent(diagram.title, forKey: .title)
            try container.encode(diagram.nodes, forKey: .nodes)
            try container.encodeIfPresent(diagram.caption, forKey: .caption)

        case .chart(let chart):
            try container.encode(Kind.chart.rawValue, forKey: .type)
            try container.encode(chart.kind, forKey: .kind)
            try container.encodeIfPresent(chart.title, forKey: .title)
            try container.encode(chart.bars, forKey: .bars)
            try container.encodeIfPresent(chart.unit, forKey: .unit)
            try container.encodeIfPresent(chart.caption, forKey: .caption)

        case .formula(let latex, let caption):
            try container.encode(Kind.formula.rawValue, forKey: .type)
            try container.encode(latex, forKey: .latex)
            try container.encodeIfPresent(caption, forKey: .caption)

        case .figure(let figure):
            try container.encode(Kind.figure.rawValue, forKey: .type)
            try container.encode(figure.caption, forKey: .caption)
            try container.encodeIfPresent(figure.page, forKey: .page)
            try container.encodeIfPresent(figure.crop, forKey: .crop)
            try container.encodeIfPresent(figure.imageData.map(SheetFigureImage.encode), forKey: .image)
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

    /// Intitulé posé au-dessus de l'encadré. Il était écrit en français dans le code, alors
    /// que le site le prend depuis les catalogues partagés : c'est le même encadré.
    var label: String {
        L10n.t("app.sheetTone.\(rawValue)", locale: .resolved())
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

// MARK: - Chiffre clé

/// Une valeur, et ce qu'elle mesure.
///
/// Les deux vont ensemble et le libellé n'est pas décoratif : « 0,05 » posé seul sur une
/// fiche de statistiques ne veut rien dire, et c'est pourtant exactement le genre de valeur
/// qu'on vient chercher la veille d'une épreuve.
struct SheetKeypoint: Codable, Equatable, Sendable {
    /// Le chiffre, avec son unité : « 37 °C », « 0,05 », « 1789 ».
    var value: String
    /// Ce qu'il mesure, en trois ou quatre mots.
    var label: String

    init(value: String, label: String) {
        self.value = value
        self.label = label
    }

    private enum CodingKeys: String, CodingKey {
        case value, label
    }

    /// La valeur peut arriver en nombre : `{"value": 37}` est aussi juste que `"37 °C"`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = (try? container.decode(SheetScalar.self, forKey: .value))?.text ?? ""
        label = (try? container.decode(String.self, forKey: .label)) ?? ""
    }

    func sanitized() -> SheetKeypoint? {
        guard let value = SheetText.clean(value), let label = SheetText.clean(label) else { return nil }
        return SheetKeypoint(value: value, label: label)
    }
}

// MARK: - Question

/// Une question et sa réponse, posées dans la fiche.
///
/// Ce n'est pas une carte : ça ne se planifie pas, ça ne se note pas, et ça ne quitte pas la
/// page. C'est le geste qu'on fait à la main sur une fiche papier — cacher la réponse avec le
/// doigt pour voir si elle vient — et c'est la seule façon de savoir si on a lu ou compris.
struct SheetQuestion: Codable, Equatable, Sendable {
    var question: String
    var answer: String

    init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }

    func sanitized() -> SheetQuestion? {
        guard let question = SheetText.clean(question), let answer = SheetText.clean(answer) else { return nil }
        return SheetQuestion(question: question, answer: answer)
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

// MARK: - Schéma

/// Le schéma de la fiche : **dessiné par l'application**, à partir de ce que le modèle a
/// compris du cours.
///
/// C'est le manque le plus visible d'une fiche de révision sans figure, et il y a trois
/// façons de le combler. Demander une image à un modèle génératif en est une, et c'est la
/// mauvaise : sur un schéma, ce qui compte est le libellé des étapes et le sens des flèches,
/// or c'est exactement ce qu'un modèle d'image écrit de travers. Reprendre la figure du
/// document en est une autre, et elle a son bloc. Celle-ci est la troisième : le modèle rend
/// des **nœuds nommés** et une disposition, et le dessin est fait ici, à la typographie de
/// l'app, net à toutes les tailles et lisible par un lecteur d'écran.
///
/// Quatre dispositions, et pas une de plus. Chacune a son rendu dessiné pour elle : un format
/// ouvert où le modèle inventerait sa figure donnerait une page différente à chaque cours.
struct SheetDiagram: Equatable, Sendable {
    /// Ce que la figure montre. C'est la question à laquelle un schéma répond, et il n'y en a
    /// que quatre sur une fiche de cours.
    enum Layout: String, Codable, Equatable, CaseIterable, Sendable {
        /// Une suite : A mène à B, qui mène à C.
        case flow
        /// Une boucle : la même suite, qui revient à son point de départ.
        case cycle
        /// Une classification : un tronc, et ce qui s'y rattache.
        case branch
        /// Une frise : des dates, dans l'ordre.
        case timeline

        /// Le modèle écrit « process », « steps » ou « chronologie » : on retombe sur la
        /// disposition la plus proche plutôt que de perdre la figure.
        init(from decoder: Decoder) throws {
            let raw = (try? decoder.singleValueContainer().decode(String.self))?
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .trimmingCharacters(in: .whitespaces) ?? ""

            switch raw {
            case "cycle", "loop", "boucle": self = .cycle
            case "branch", "tree", "arbre", "classification", "taxonomie": self = .branch
            case "timeline", "frise", "chronologie", "dates": self = .timeline
            default: self = .flow
            }
        }
    }

    /// Une case du schéma.
    struct Node: Codable, Equatable, Sendable {
        /// Ce que la case dit : trois ou quatre mots, jamais une phrase. Une case qui porte
        /// une phrase entière est un paragraphe qui s'est trompé de bloc.
        var label: String
        /// La précision sous le libellé, et la date sur une frise.
        var detail: String?

        init(label: String, detail: String? = nil) {
            self.label = label
            self.detail = detail
        }

        func sanitized() -> Node? {
            guard let label = SheetText.clean(label) else { return nil }
            return Node(label: label, detail: detail.flatMap(SheetText.clean))
        }
    }

    var layout: Layout
    var title: String?
    var nodes: [Node]
    var caption: String?

    init(layout: Layout, title: String? = nil, nodes: [Node], caption: String? = nil) {
        self.layout = layout
        self.title = title
        self.nodes = nodes
        self.caption = caption
    }

    /// Le tronc d'une classification, c'est-à-dire la première case.
    var trunk: Node? {
        layout == .branch ? nodes.first : nil
    }

    /// Ce qui se rattache au tronc, ou toutes les cases pour les trois autres dispositions.
    var branches: [Node] {
        layout == .branch ? Array(nodes.dropFirst()) : nodes
    }

    /// La figure à plat, telle qu'elle part au modèle pour écrire des cartes.
    ///
    /// La flèche est **écrite** : « Évaporation → Condensation » se révise, deux libellés
    /// séparés par une virgule ne disent plus qu'il y a une suite entre eux.
    func plainLines() -> [String] {
        var lines: [String] = []
        if let title = title?.nilIfBlank { lines.append(SheetMarkup.plain(title)) }

        let labels = nodes.map { node -> String in
            let label = SheetMarkup.plain(node.label)
            guard let detail = node.detail?.nilIfBlank else { return label }
            return "\(label) (\(SheetMarkup.plain(detail)))"
        }

        switch layout {
        case .flow:
            lines.append(labels.joined(separator: " → "))
        case .cycle:
            lines.append((labels + labels.prefix(1)).joined(separator: " → "))
        case .timeline:
            lines.append(labels.joined(separator: ", puis "))
        case .branch:
            guard let trunk = labels.first else { break }
            lines.append("\(trunk) : \(labels.dropFirst().joined(separator: ", "))")
        }

        if let caption = caption?.nilIfBlank { lines.append(SheetMarkup.plain(caption)) }
        return lines
    }

    /// Une case ne fait pas un schéma, et une classification a besoin d'un tronc **et** de
    /// deux branches : sinon c'est une définition.
    func sanitized() -> SheetDiagram? {
        let clean = nodes.compactMap { $0.sanitized() }
        let minimum = layout == .branch ? 3 : 2
        guard clean.count >= minimum else { return nil }

        return SheetDiagram(
            layout: layout,
            title: title.flatMap(SheetText.clean),
            nodes: Array(clean.prefix(SheetLimits.diagramNodes)),
            caption: caption.flatMap(SheetText.clean)
        )
    }
}

// MARK: - Graphe

/// Le graphe de la fiche.
///
/// Micabo n'essaie pas de reproduire les figures du document, ce serait toujours moins bon
/// que l'original. Il ne dessine que ce qui se compare : des valeurs nommées, dans la même
/// unité, mises côte à côte.
struct SheetChart: Equatable, Sendable {
    /// La forme du graphe.
    ///
    /// Il n'y avait que des barres, et une barre ne sait dire qu'une chose : « celui-ci est
    /// plus grand que celui-là ». Une évolution dans le temps posée en barres se lit de
    /// travers, et une répartition en barres perd le fait que le tout fait cent pour cent.
    /// Ce sont les trois seules questions qu'un graphe de fiche a à traiter.
    enum Kind: String, Codable, Equatable, CaseIterable, Sendable {
        /// Des valeurs qui se comparent, en barres couchées : c'est la forme qui laisse la
        /// place d'écrire les libellés en entier sur un téléphone.
        case bars
        /// Les mêmes valeurs debout, quand les libellés sont courts et l'ordre significatif.
        case columns
        /// Une évolution : les points sont ordonnés, et la ligne qui les joint est le propos.
        case line
        /// Une répartition : les parts d'un même tout.
        case donut

        init(from decoder: Decoder) throws {
            let raw = (try? decoder.singleValueContainer().decode(String.self))?
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .trimmingCharacters(in: .whitespaces) ?? ""

            switch raw {
            case "columns", "column", "vertical", "colonnes": self = .columns
            case "line", "ligne", "courbe", "evolution": self = .line
            case "donut", "pie", "camembert", "repartition", "part": self = .donut
            default: self = .bars
            }
        }
    }

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

    var kind: Kind
    var title: String?
    /// Les valeurs du graphe. Le nom est resté `bars` : c'est la clé écrite dans les fiches
    /// déjà en base, et la renommer les aurait toutes vidées de leurs graphes. Sur une
    /// courbe, ce sont les points dans l'ordre ; sur un anneau, les parts.
    var bars: [Bar]
    var unit: String?
    var caption: String?

    init(kind: Kind = .bars, title: String? = nil, bars: [Bar], unit: String? = nil, caption: String? = nil) {
        self.kind = kind
        self.title = title
        self.bars = bars
        self.unit = unit
        self.caption = caption
    }

    /// Le total des parts, qui n'a de sens que sur un anneau.
    var total: Double {
        bars.reduce(0) { $0 + $1.value }
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
            kind: kind,
            title: title.flatMap(SheetText.clean),
            // Une courbe a droit à plus de points qu'un histogramme n'a de barres : c'est
            // même ce qui en fait une courbe. Six points sur une évolution, c'est une ligne
            // brisée.
            bars: Array(cleanBars.prefix(kind == .line ? SheetLimits.chartPoints : SheetLimits.chartBars)),
            unit: unit.flatMap(SheetText.clean),
            caption: caption.flatMap(SheetText.clean)
        )
    }
}

// MARK: - Figure recadrée

/// Une figure coupée dans une page du document, pas un schéma inventé.
struct SheetFigure: Equatable, Sendable {
    var caption: String
    var page: Int?
    var crop: SheetCrop?
    var imageData: Data?

    func sanitized() -> SheetFigure? {
        let clean = SheetText.clean(caption)
        guard let clean, clean.count >= 4 else { return nil }
        guard page != nil || imageData != nil else { return nil }
        return SheetFigure(caption: clean, page: page, crop: crop?.clamped(), imageData: imageData)
    }
}

/// Rectangle normalisé (0...1), origine en haut à gauche de la page.
struct SheetCrop: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = Self.number(container, .x) ?? 0
        y = Self.number(container, .y) ?? 0
        w = Self.number(container, .w) ?? 0
        h = Self.number(container, .h) ?? 0
    }

    private enum CodingKeys: String, CodingKey { case x, y, w, h }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(w, forKey: .w)
        try container.encode(h, forKey: .h)
    }

    private static func number(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(value.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    func clamped() -> SheetCrop? {
        var crop = SheetCrop(
            x: min(max(x, 0), 0.95),
            y: min(max(y, 0), 0.95),
            w: min(max(w, 0.08), 1),
            h: min(max(h, 0.08), 1)
        )
        if crop.x + crop.w > 1 { crop.w = 1 - crop.x }
        if crop.y + crop.h > 1 { crop.h = 1 - crop.y }
        guard crop.w >= 0.08, crop.h >= 0.08 else { return nil }
        return crop
    }

    var asRect: CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }
}

enum SheetFigureImage {
    static func decode(_ raw: String?) -> Data? {
        guard let raw else { return nil }
        let payload: Substring
        if let range = raw.range(of: "base64,") {
            payload = raw[range.upperBound...]
        } else {
            payload = Substring(raw)
        }
        let compact = payload.filter { !$0.isWhitespace }
        guard compact.count >= 32 else { return nil }
        return Data(base64Encoded: String(compact))
    }

    static func encode(_ data: Data) -> String {
        "data:image/jpeg;base64," + data.base64EncodedString()
    }
}

extension CourseSheet {
    /// Coupe les pages encore disponibles et les colle dans les blocs figure.
    ///
    /// Le serveur le fait déjà quand il le peut. Ici c'est le filet : une fiche arrivée
    /// avec des coordonnées et les JPEG d'import, mais sans `image`, resterait muette.
    func attachingFigureImages(from pages: [Data]) -> CourseSheet {
        guard !pages.isEmpty else { return self }
        let next = blocks.map { block -> SheetBlock in
            guard case .figure(var figure) = block, figure.imageData == nil else { return block }
            let index = (figure.page ?? 1) - 1
            guard pages.indices.contains(index) else { return block }
            figure.imageData = SheetFigureCropper.crop(pages[index], crop: figure.crop)
            return .figure(figure)
        }
        return CourseSheet(blocks: next)
    }
}

enum SheetFigureCropper {
    static func crop(_ page: Data, crop: SheetCrop?, maxDimension: CGFloat = 720) -> Data? {
        guard let image = UIImage(data: page) else { return nil }
        let box = crop?.clamped()?.asRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        let pixel = CGRect(
            x: box.origin.x * image.size.width,
            y: box.origin.y * image.size.height,
            width: max(8, box.size.width * image.size.width),
            height: max(8, box.size.height * image.size.height)
        )
        let clipped = CGRect(origin: .zero, size: image.size).intersection(pixel)
        guard clipped.width >= 8, clipped.height >= 8 else { return ImagePrep.jpeg(image, maxDimension: maxDimension) }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: clipped.size, format: format)
        let cut = renderer.image { _ in
            image.draw(at: CGPoint(x: -clipped.origin.x, y: -clipped.origin.y))
        }
        return ImagePrep.jpeg(cut, maxDimension: maxDimension, quality: 0.7)
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
    static let listItems = 6
    static let stepsPerBlock = 7
    static let keypoints = 4
    static let quizItems = 3
    static let tableColumns = 4
    static let tableRows = 8
    static let diagramNodes = 6
    static let chartBars = 6
    /// Les points d'une courbe, qui n'est pas un histogramme couché.
    static let chartPoints = 12
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
