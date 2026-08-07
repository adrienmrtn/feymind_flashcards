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

    /// Retire le balisage court que le modèle ajoute parfois : plus rien ne le rend à l'écran.
    static func removeInlineMarkup(_ text: String) -> String {
        var result = text
        for marker in ["**", "==", "`", "*", "_"] {
            result = result.replacingOccurrences(of: marker, with: "")
        }
        return result
    }

    static func clean(_ text: String) -> String {
        removeInlineMarkup(removeEmDashes(text)).trimmingCharacters(in: .whitespacesAndNewlines)
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
}

extension GeneratedCourse {
    /// Nettoie tous les textes produits par le modèle avant enregistrement.
    func sanitized() -> GeneratedCourse {
        GeneratedCourse(
            title: TextSanitizer.clean(title),
            subject: subject.map(TextSanitizer.clean),
            emoji: emoji,
            summary: TextSanitizer.clean(summary),
            contextText: TextSanitizer.clean(contextText)
        )
    }
}
