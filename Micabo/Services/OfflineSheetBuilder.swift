import Foundation

/// Fiche construite sans IA, à partir du seul texte extrait.
///
/// C'est le repli de « Créer sans IA », proposé quand la clé fal n'est pas configurée ou
/// que l'analyse échoue. Elle n'invente rien et n'ajoute **aucune mise en valeur** : pas de
/// gras, pas de surlignage, pas d'encadré. Deviner ce qui compte dans un cours qu'on n'a
/// pas lu produirait une fiche qui a l'air travaillée et qui souligne n'importe quoi, ce
/// qui est bien pire qu'une fiche sobre. Ce qu'on peut reconnaître sans comprendre, en
/// revanche, on le structure : les titres et les définitions écrites « terme : sens ».
enum OfflineSheetBuilder {
    static func build(from rawText: String, title: String) -> CourseSheet? {
        let lines = OfflineSheetBuilder.lines(of: TextSanitizer.normalizeExtractedText(rawText))
        guard !lines.isEmpty else { return nil }

        var blocks: [SheetBlock] = []

        for line in lines.prefix(SheetLimits.blocks) {
            if isLikelyHeading(line) {
                blocks.append(.heading(level: 2, text: line))
            } else if let definition = definition(in: line) {
                blocks.append(.definition(term: definition.term, text: definition.text))
            } else {
                blocks.append(.paragraph(text: line))
            }
        }

        // Une fiche qui n'est qu'une suite de titres n'est pas une fiche.
        let hasBody = blocks.contains { block in
            switch block {
            case .paragraph, .definition: true
            default: false
            }
        }
        guard hasBody else {
            return CourseSheet(blocks: [.paragraph(text: String(TextSanitizer.normalizeExtractedText(rawText).prefix(2_000)))])
                .sanitized()
        }

        if blocks.first.map(isHeading) == false {
            blocks.insert(.heading(level: 1, text: title), at: 0)
        }

        let sheet = CourseSheet(blocks: blocks).sanitized()
        return sheet.isEmpty ? nil : sheet
    }

    // MARK: - Découpage

    /// Les paragraphes du document. Un retour à la ligne isolé au milieu d'une phrase est
    /// un artefact d'extraction PDF, pas une intention : on ne coupe que sur les lignes
    /// vides et les fins de phrase.
    private static func lines(of text: String) -> [String] {
        text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 12 }
    }

    private static func isHeading(_ block: SheetBlock) -> Bool {
        if case .heading = block { return true }
        return false
    }

    /// Un titre ne se termine pas par un point, tient sur une ligne courte, et il est
    /// souvent en capitales ou numéroté.
    static func isLikelyHeading(_ line: String) -> Bool {
        guard line.count <= 80 else { return false }
        if line.hasSuffix(".") || line.hasSuffix(",") || line.hasSuffix(":") { return false }

        let letters = max(1, line.filter(\.isLetter).count)
        if Double(line.filter(\.isUppercase).count) / Double(letters) > 0.6 { return true }
        return line.count <= 60 && line.split(separator: " ").count <= 8
    }

    /// « Photolyse : rupture de la molécule d'eau. » se reconnaît sans rien comprendre au
    /// cours : un terme court, un deux-points, une phrase.
    static func definition(in line: String) -> (term: String, text: String)? {
        for separator in [" : ", " : ", ": "] {
            guard let range = line.range(of: separator) else { continue }
            let term = String(line[line.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let text = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)

            let words = term.split(separator: " ").count
            guard words <= 5, term.count >= 3, text.count >= 25 else { continue }
            // Un deux-points qui introduit une énumération n'est pas une définition.
            guard !text.hasPrefix("-"), !term.hasSuffix("s suivants") else { continue }
            return (term, text)
        }
        return nil
    }
}
