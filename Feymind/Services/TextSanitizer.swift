import Foundation

enum TextSanitizer {
    /// Feymind bannit les tirets cadratins : le modèle en produit parfois malgré la consigne.
    static func removeEmDashes(_ text: String) -> String {
        var result = text
        let separators: [(String, String)] = [
            (" — ", ", "),
            (" – ", ", "),
            (" ― ", ", "),
            ("— ", ""),
            ("– ", ""),
            (" —", ""),
            (" –", "")
        ]
        for (pattern, replacement) in separators {
            result = result.replacingOccurrences(of: pattern, with: replacement)
        }
        result = result.replacingOccurrences(of: "—", with: "-")
        result = result.replacingOccurrences(of: "–", with: "-")
        result = result.replacingOccurrences(of: "―", with: "-")
        return result
    }

    static func clean(_ text: String) -> String {
        removeEmDashes(text).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Compacte les espaces et sauts de ligne d'un texte extrait d'un PDF.
    static func normalizeExtractedText(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\u{00AD}", with: "")
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func estimatedReadingMinutes(for text: String) -> Int {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        return max(1, Int((Double(words) / 200.0).rounded(.up)))
    }
}

extension GeneratedCourse {
    /// Nettoie tous les textes produits par le modèle avant enregistrement.
    func sanitized() -> GeneratedCourse {
        var copy = self
        copy.title = TextSanitizer.clean(title)
        copy.summary = TextSanitizer.clean(summary)
        copy.subject = subject.map(TextSanitizer.clean)
        copy.blocks = blocks.map { $0.sanitized() }
        return copy
    }
}

extension CourseBlockPayload {
    func sanitized() -> CourseBlockPayload {
        let clean = TextSanitizer.removeEmDashes

        switch self {
        case .heading(var block):
            block.text = clean(block.text)
            return .heading(block)
        case .paragraph(var block):
            block.text = clean(block.text)
            return .paragraph(block)
        case .list(var block):
            block.items = block.items.map(clean)
            return .list(block)
        case .keyPoints(var block):
            block.title = block.title.map(clean)
            block.items = block.items.map(clean)
            return .keyPoints(block)
        case .callout(var block):
            block.title = block.title.map(clean)
            block.text = clean(block.text)
            return .callout(block)
        case .definition(var block):
            block.term = clean(block.term)
            block.text = clean(block.text)
            return .definition(block)
        case .formula(var block):
            block.caption = block.caption.map(clean)
            return .formula(block)
        case .table(var block):
            block.headers = block.headers.map(clean)
            block.rows = block.rows.map { $0.map(clean) }
            return .table(block)
        case .quote(var block):
            block.text = clean(block.text)
            block.author = block.author.map(clean)
            return .quote(block)
        case .divider:
            return .divider
        case .flow(var block):
            block.title = block.title.map(clean)
            block.steps = block.steps.map { StepItem(label: clean($0.label), detail: $0.detail.map(clean)) }
            return .flow(block)
        case .cycle(var block):
            block.title = block.title.map(clean)
            block.steps = block.steps.map { StepItem(label: clean($0.label), detail: $0.detail.map(clean)) }
            return .cycle(block)
        case .tree(var block):
            block.title = block.title.map(clean)
            block.root = Self.sanitizeNode(block.root)
            return .tree(block)
        case .comparison(var block):
            block.title = block.title.map(clean)
            block.columns = block.columns.map { ComparisonColumn(title: clean($0.title), items: $0.items.map(clean)) }
            return .comparison(block)
        case .timeline(var block):
            block.title = block.title.map(clean)
            block.events = block.events.map {
                TimelineEvent(date: clean($0.date), label: clean($0.label), detail: $0.detail.map(clean))
            }
            return .timeline(block)
        case .chart(var block):
            block.title = block.title.map(clean)
            block.caption = block.caption.map(clean)
            block.bars = block.bars.map { ChartBar(label: clean($0.label), value: $0.value, unit: $0.unit) }
            return .chart(block)
        }
    }

    private static func sanitizeNode(_ node: TreeNode) -> TreeNode {
        TreeNode(
            label: TextSanitizer.removeEmDashes(node.label),
            detail: node.detail.map(TextSanitizer.removeEmDashes),
            children: node.children?.map(sanitizeNode)
        )
    }
}
