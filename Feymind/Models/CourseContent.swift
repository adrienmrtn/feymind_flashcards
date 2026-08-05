import Foundation

// MARK: - Blocs

struct HeadingBlock: Codable, Hashable {
    /// 1, 2 ou 3.
    var level: Int
    var text: String
}

struct ParagraphBlock: Codable, Hashable {
    var text: String
}

struct ListBlock: Codable, Hashable {
    var ordered: Bool
    var items: [String]
}

struct KeyPointsBlock: Codable, Hashable {
    var title: String?
    var items: [String]
}

enum CalloutVariant: String, Codable, Hashable, CaseIterable {
    case info
    case important
    case warning
    case tip
    case example
    case memo

    var systemImage: String {
        switch self {
        case .info: "info.circle.fill"
        case .important: "star.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .tip: "lightbulb.fill"
        case .example: "text.book.closed.fill"
        case .memo: "brain.head.profile"
        }
    }

    var label: String {
        switch self {
        case .info: "Info"
        case .important: "Important"
        case .warning: "Attention"
        case .tip: "Astuce"
        case .example: "Exemple"
        case .memo: "À retenir"
        }
    }
}

struct CalloutBlock: Codable, Hashable {
    var variant: CalloutVariant
    var title: String?
    var text: String
}

struct DefinitionBlock: Codable, Hashable {
    var term: String
    var text: String
}

struct FormulaBlock: Codable, Hashable {
    var expression: String
    var caption: String?
}

struct TableBlock: Codable, Hashable {
    var headers: [String]
    var rows: [[String]]
}

struct QuoteBlock: Codable, Hashable {
    var text: String
    var author: String?
}

struct StepItem: Codable, Hashable {
    var label: String
    var detail: String?
}

struct FlowBlock: Codable, Hashable {
    var title: String?
    var steps: [StepItem]
}

struct CycleBlock: Codable, Hashable {
    var title: String?
    var steps: [StepItem]
}

struct TreeNode: Codable, Hashable {
    var label: String
    var detail: String?
    var children: [TreeNode]?
}

struct TreeBlock: Codable, Hashable {
    var title: String?
    var root: TreeNode
}

struct ComparisonColumn: Codable, Hashable {
    var title: String
    var items: [String]
}

struct ComparisonBlock: Codable, Hashable {
    var title: String?
    var columns: [ComparisonColumn]
}

struct TimelineEvent: Codable, Hashable {
    var date: String
    var label: String
    var detail: String?
}

struct TimelineBlock: Codable, Hashable {
    var title: String?
    var events: [TimelineEvent]
}

struct ChartBar: Codable, Hashable {
    var label: String
    var value: Double
    var unit: String?
}

struct ChartBlock: Codable, Hashable {
    var title: String?
    var caption: String?
    var bars: [ChartBar]
}

// MARK: - Enveloppe

enum CourseBlockKind: String, Codable, CaseIterable {
    case heading
    case paragraph
    case list
    case keyPoints
    case callout
    case definition
    case formula
    case table
    case quote
    case divider
    case flow
    case cycle
    case tree
    case comparison
    case timeline
    case chart
}

enum CourseBlockPayload: Codable, Hashable {
    case heading(HeadingBlock)
    case paragraph(ParagraphBlock)
    case list(ListBlock)
    case keyPoints(KeyPointsBlock)
    case callout(CalloutBlock)
    case definition(DefinitionBlock)
    case formula(FormulaBlock)
    case table(TableBlock)
    case quote(QuoteBlock)
    case divider
    case flow(FlowBlock)
    case cycle(CycleBlock)
    case tree(TreeBlock)
    case comparison(ComparisonBlock)
    case timeline(TimelineBlock)
    case chart(ChartBlock)

    var kind: CourseBlockKind {
        switch self {
        case .heading: .heading
        case .paragraph: .paragraph
        case .list: .list
        case .keyPoints: .keyPoints
        case .callout: .callout
        case .definition: .definition
        case .formula: .formula
        case .table: .table
        case .quote: .quote
        case .divider: .divider
        case .flow: .flow
        case .cycle: .cycle
        case .tree: .tree
        case .comparison: .comparison
        case .timeline: .timeline
        case .chart: .chart
        }
    }

    /// Texte brut du bloc, utilisé pour construire le contexte envoyé à l'IA.
    var plainText: String {
        switch self {
        case .heading(let block): block.text
        case .paragraph(let block): block.text
        case .list(let block): block.items.joined(separator: "\n")
        case .keyPoints(let block): ((block.title.map { $0 + "\n" }) ?? "") + block.items.joined(separator: "\n")
        case .callout(let block): ((block.title.map { $0 + "\n" }) ?? "") + block.text
        case .definition(let block): "\(block.term) : \(block.text)"
        case .formula(let block): block.expression + (block.caption.map { "\n" + $0 } ?? "")
        case .table(let block): ([block.headers] + block.rows).map { $0.joined(separator: " | ") }.joined(separator: "\n")
        case .quote(let block): block.text
        case .divider: ""
        case .flow(let block): block.steps.map(\.label).joined(separator: " puis ")
        case .cycle(let block): block.steps.map(\.label).joined(separator: " puis ")
        case .tree(let block): TreeNodeFlattener.flatten(block.root).joined(separator: "\n")
        case .comparison(let block): block.columns.map { "\($0.title) : \($0.items.joined(separator: ", "))" }.joined(separator: "\n")
        case .timeline(let block): block.events.map { "\($0.date) : \($0.label)" }.joined(separator: "\n")
        case .chart(let block): block.bars.map { "\($0.label) : \($0.value)" }.joined(separator: "\n")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawKind = try container.decode(String.self, forKey: .type)
        guard let kind = CourseBlockKind(rawValue: rawKind) else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Type de bloc inconnu : \(rawKind)"
            )
        }

        let single = decoder
        switch kind {
        case .heading: self = .heading(try HeadingBlock(from: single))
        case .paragraph: self = .paragraph(try ParagraphBlock(from: single))
        case .list: self = .list(try ListBlock(from: single))
        case .keyPoints: self = .keyPoints(try KeyPointsBlock(from: single))
        case .callout: self = .callout(try CalloutBlock(from: single))
        case .definition: self = .definition(try DefinitionBlock(from: single))
        case .formula: self = .formula(try FormulaBlock(from: single))
        case .table: self = .table(try TableBlock(from: single))
        case .quote: self = .quote(try QuoteBlock(from: single))
        case .divider: self = .divider
        case .flow: self = .flow(try FlowBlock(from: single))
        case .cycle: self = .cycle(try CycleBlock(from: single))
        case .tree: self = .tree(try TreeBlock(from: single))
        case .comparison: self = .comparison(try ComparisonBlock(from: single))
        case .timeline: self = .timeline(try TimelineBlock(from: single))
        case .chart: self = .chart(try ChartBlock(from: single))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.rawValue, forKey: .type)

        switch self {
        case .heading(let block): try block.encode(to: encoder)
        case .paragraph(let block): try block.encode(to: encoder)
        case .list(let block): try block.encode(to: encoder)
        case .keyPoints(let block): try block.encode(to: encoder)
        case .callout(let block): try block.encode(to: encoder)
        case .definition(let block): try block.encode(to: encoder)
        case .formula(let block): try block.encode(to: encoder)
        case .table(let block): try block.encode(to: encoder)
        case .quote(let block): try block.encode(to: encoder)
        case .divider: break
        case .flow(let block): try block.encode(to: encoder)
        case .cycle(let block): try block.encode(to: encoder)
        case .tree(let block): try block.encode(to: encoder)
        case .comparison(let block): try block.encode(to: encoder)
        case .timeline(let block): try block.encode(to: encoder)
        case .chart(let block): try block.encode(to: encoder)
        }
    }
}

enum TreeNodeFlattener {
    static func flatten(_ node: TreeNode, depth: Int = 0) -> [String] {
        let indent = String(repeating: "  ", count: depth)
        var lines = [indent + node.label]
        for child in node.children ?? [] {
            lines.append(contentsOf: flatten(child, depth: depth + 1))
        }
        return lines
    }
}

// MARK: - Cours généré

/// Résultat brut renvoyé par l'IA avant enregistrement en base.
struct GeneratedCourse: Codable {
    var title: String
    var subject: String?
    var emoji: String?
    var summary: String
    var readingMinutes: Int?
    var blocks: [CourseBlockPayload]

    private enum CodingKeys: String, CodingKey {
        case title, subject, emoji, summary, readingMinutes, blocks
    }

    init(
        title: String,
        subject: String? = nil,
        emoji: String? = nil,
        summary: String,
        readingMinutes: Int? = nil,
        blocks: [CourseBlockPayload]
    ) {
        self.title = title
        self.subject = subject
        self.emoji = emoji
        self.summary = summary
        self.readingMinutes = readingMinutes
        self.blocks = blocks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? container.decode(String.self, forKey: .title)) ?? "Cours sans titre"
        subject = try? container.decodeIfPresent(String.self, forKey: .subject)
        emoji = try? container.decodeIfPresent(String.self, forKey: .emoji)
        summary = (try? container.decode(String.self, forKey: .summary)) ?? ""
        readingMinutes = try? container.decodeIfPresent(Int.self, forKey: .readingMinutes)

        // Un bloc mal formé ne doit pas faire échouer tout le cours.
        var blocksContainer = try container.nestedUnkeyedContainer(forKey: .blocks)
        var decoded: [CourseBlockPayload] = []
        while !blocksContainer.isAtEnd {
            let indexBefore = blocksContainer.currentIndex
            if let block = try? blocksContainer.decode(CourseBlockPayload.self) {
                decoded.append(block)
            } else {
                _ = try? blocksContainer.decode(AnyDecodableValue.self)
            }
            guard blocksContainer.currentIndex > indexBefore else { break }
        }
        blocks = decoded
    }
}

/// Utilisé uniquement pour consommer un élément illisible dans un tableau JSON.
private struct AnyDecodableValue: Decodable {
    init(from decoder: Decoder) throws {
        _ = try? decoder.singleValueContainer()
    }
}
