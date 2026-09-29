import Foundation
import SwiftData

// MARK: - Un cours de démonstration

/// **Un cours embarqué, pour qui n'a pas ses supports sous la main.**
///
/// Le parcours promet une fiche, et il la montre : à qui n'a rien à déposer, il propose
/// quatre cours écrits d'avance, dans quatre matières, et les traite comme un cours
/// généré — même écran de construction, même plan, mêmes chapitres, mêmes cartes. Le
/// cours **entre dans la bibliothèque** comme n'importe quel autre (`install`), pour que
/// ce qu'on a vu pendant le parcours soit encore là après.
///
/// **Il est plus riche qu'une fiche réelle.** Une fiche générée n'a que des blocs texte —
/// titres, paragraphes, listes, formules, surlignage —, parce qu'elle doit rester
/// modifiable au doigt. Celui-ci porte en plus des schémas, des tableaux, des graphes et des
/// encadrés, dessinés par l'app (`DemoSheetView`) : c'est la démonstration, elle a le droit
/// d'être belle. Dans la bibliothèque, ces blocs riches se lisent **convertis en texte**
/// (`sheetBlocks`), comme les anciens blocs des fiches d'avant.
struct OnboardingDemoCourse: Identifiable {
    let id: String
    let emoji: String
    /// La matière, telle que la liste la range.
    let subject: String
    let title: String
    let summary: String
    /// Le rang de la teinte de cours, dans `MicaboColor.courseAccents`.
    let accentIndex: Int
    let chapters: [DemoChapter]
    /// Les cartes, **les trois de l'entraînement en tête** : une recto verso avec sa
    /// figure, un QCM, un texte à trou. Les suivantes entrent dans le deck avec elles.
    let cards: [DemoCard]

    var cardCount: Int { cards.count }

    /// La fiche entière, telle qu'elle s'enregistre : chaque chapitre ouvre sur son titre de
    /// partie, et c'est ce titre que `ChapterBuilder` retrouve pour découper le plan.
    var sheet: CourseSheet {
        CourseSheet(blocks: chapters.flatMap { chapter in
            [SheetBlock.heading(level: 1, text: chapter.title)] + chapter.blocks.flatMap { $0.sheetBlocks }
        })
    }

    /// Les trois cartes de l'entraînement.
    var trainingCards: [DemoCard] {
        let basic = cards.first { $0.kind == .basic }
        let choice = cards.first { $0.kind == .choice }
        let cloze = cards.first { $0.kind == .cloze }
        return [basic, choice, cloze].compactMap { $0 }
    }
}

struct DemoChapter {
    let title: String
    let blocks: [DemoBlock]
}

/// Un bloc de la fiche de démonstration : soit un bloc de fiche ordinaire, soit un objet
/// riche que seule la démonstration sait dessiner.
enum DemoBlock {
    case sheet(SheetBlock)
    case callout(title: String, text: String, tone: DemoTone)
    case table(title: String?, headers: [String], rows: [[String]])
    case bars(title: String, unit: String?, bars: [DemoBar])
    case timeline(title: String?, events: [DemoEvent])
    case figure(DemoFigure)
    case keyFigure(value: String, label: String)

    static func heading(_ text: String) -> DemoBlock { .sheet(.heading(level: 2, text: text)) }
    static func paragraph(_ text: String) -> DemoBlock { .sheet(.paragraph(text: text)) }
    static func list(_ items: [String], ordered: Bool = false) -> DemoBlock { .sheet(.list(ordered: ordered, items: items)) }
    static func formula(_ latex: String, caption: String? = nil) -> DemoBlock { .sheet(.formula(latex: latex, caption: caption)) }

    /// **Ce que le bloc vaut en texte**, pour la fiche enregistrée. La même règle que les
    /// anciens blocs des fiches : un tableau devient ses lignes, un graphe ses valeurs, un
    /// schéma la liste de ce qu'il relie.
    var sheetBlocks: [SheetBlock] {
        switch self {
        case .sheet(let block):
            return [block]
        case .callout(let title, let text, _):
            return [.paragraph(text: "**\(title)** : \(text)")]
        case .table(let title, let headers, let rows):
            let items = rows.map { row in
                row.enumerated()
                    .filter { !$0.element.isEmpty }
                    .map { entry -> String in
                        let header = headers.indices.contains(entry.offset) ? headers[entry.offset] : ""
                        return header.isEmpty ? entry.element : "**\(header)** : \(entry.element)"
                    }
                    .joined(separator: ", ")
            }
            return titled(title) + [.list(ordered: false, items: items)]
        case .bars(let title, let unit, let bars):
            let items = bars.map { "**\($0.label)** : \($0.valueText)\(unit.map { " \($0)" } ?? "")" }
            return [.heading(level: 2, text: title), .list(ordered: false, items: items)]
        case .timeline(let title, let events):
            return titled(title) + [.list(ordered: false, items: events.map { "**\($0.date)** : \($0.label)" })]
        case .figure(let figure):
            return figure.sheetBlocks
        case .keyFigure(let value, let label):
            return [.paragraph(text: "**\(value)** — \(label)")]
        }
    }

    private func titled(_ title: String?) -> [SheetBlock] {
        guard let title = title?.nilIfBlank else { return [] }
        return [.heading(level: 2, text: title)]
    }
}

/// La couleur d'un encadré, selon ce qu'il dit.
enum DemoTone {
    case definition
    case insight
    case warning
    case example
}

struct DemoBar {
    let label: String
    let value: Double
    /// Le texte écrit sur la barre, quand la valeur ne se lit pas telle quelle.
    var valueText: String { value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value) }
}

struct DemoEvent {
    let date: String
    let label: String
}

struct DemoColumn {
    let title: String
    let items: [String]
}

/// Un schéma dessiné par l'app.
enum DemoFigure {
    /// Des étapes en cercle, reliées par des flèches : un cycle.
    case cycle(title: String, nodes: [String])
    /// Des étapes en ligne, reliées par des flèches : un mécanisme, une chaîne.
    case flow(title: String, steps: [String])
    /// Deux colonnes face à face : deux camps, deux modèles.
    case split(title: String, left: DemoColumn, right: DemoColumn)
    /// Une courbe et sa tangente, sur des axes.
    case plot(title: String, caption: String, kind: DemoPlotKind)

    var sheetBlocks: [SheetBlock] {
        switch self {
        case .cycle(let title, let nodes):
            return [.heading(level: 2, text: title), .list(ordered: true, items: nodes)]
        case .flow(let title, let steps):
            return [.heading(level: 2, text: title), .list(ordered: true, items: steps)]
        case .split(let title, let left, let right):
            return [
                .heading(level: 2, text: title),
                .paragraph(text: "**\(left.title)** : " + left.items.joined(separator: ", ") + "."),
                .paragraph(text: "**\(right.title)** : " + right.items.joined(separator: ", ") + "."),
            ]
        case .plot(let title, let caption, _):
            return [.heading(level: 2, text: title), .paragraph(text: caption)]
        }
    }
}

enum DemoPlotKind {
    /// Une parabole et la tangente en un point.
    case tangent
    /// Une courbe qui monte puis descend, avec le signe de la pente.
    case variation
    /// Une courbe de rendement qui plafonne.
    case saturation
}

/// Une carte de démonstration : une recto verso, un QCM ou un texte à trou.
struct DemoCard: Identifiable {
    enum Kind {
        case basic
        case choice
        case cloze
    }

    let id = UUID()
    let kind: Kind
    /// Le recto. Pour un texte à trou, le trou s'écrit avec le marqueur de l'app (`…`).
    let front: String
    let back: String
    var hint: String? = nil
    var choices: [String] = []
    var answerIndex: Int = 0
    /// La figure de la carte recto verso : le schéma qui accompagne la question.
    var figure: DemoFigure? = nil
    /// Le rang du chapitre d'où vient la carte.
    var chapter: Int = 0

    /// La même carte, dans les termes de la génération, pour entrer dans le deck.
    var generated: GeneratedFlashcard {
        GeneratedFlashcard(
            front: front,
            back: back,
            hint: hint,
            kind: kindName,
            choices: kind == .choice ? choices : nil,
            answerIndex: kind == .choice ? answerIndex : nil,
            chapter: chapter
        )
    }

    private var kindName: String {
        switch kind {
        case .basic: CardKind.basic.rawValue
        case .choice: CardKind.choice.rawValue
        case .cloze: CardKind.cloze.rawValue
        }
    }
}

// MARK: - Le catalogue

/// Les quatre cours de démonstration, dans la langue de l'app.
enum OnboardingDemoCatalog {
    static func courses(locale: UiLocale) -> [OnboardingDemoCourse] {
        switch locale {
        case .fr: french
        default: english
        }
    }

    static func course(id: String, locale: UiLocale) -> OnboardingDemoCourse? {
        courses(locale: locale).first { $0.id == id }
    }

    /// **Fait entrer le cours dans la bibliothèque**, comme un cours généré : la fiche, le
    /// plan découpé à ses titres de partie, les cartes rattachées à leur chapitre.
    ///
    /// La provenance est `sample`, et c'est ce qui le tient hors du compte des cours
    /// gratuits : un cours d'exemple ne doit pas consommer le seul import offert.
    @MainActor
    @discardableResult
    static func install(
        _ demo: OnboardingDemoCourse,
        language: ContentLanguage,
        in context: ModelContext
    ) throws -> Course {
        let generated = GeneratedCourse(
            title: demo.title,
            subject: demo.subject,
            emoji: demo.emoji,
            summary: demo.summary,
            sheet: demo.sheet,
            contextText: demo.sheet.plainText()
        )
        let course = try CourseRepository.save(
            generated,
            source: .sample,
            rawText: "",
            accentIndex: demo.accentIndex,
            in: context
        )
        course.subject = demo.subject
        course.title = demo.title
        course.emoji = demo.emoji
        course.language = language

        ChapterBuilder.migrate(course, in: context)
        _ = try CourseRepository.addFlashcards(demo.cards.map(\.generated), to: course, in: context)
        try context.save()

        Analytics.track(.courseImported, [
            "source": .text(CourseSource.sample.rawValue),
            "deck": .flag(true),
            "generated": .flag(false),
            "cards": .number(Double(demo.cards.count)),
        ])
        return course
    }
}
