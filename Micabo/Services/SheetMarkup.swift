import Foundation

/// Le balisage en ligne d'une fiche.
///
/// Quatre marques, pas une de plus, et chacune a une raison d'exister sur une fiche de
/// révision :
///
/// | Écriture | Rendu | À quoi ça sert |
/// | --- | --- | --- |
/// | `**terme**` | gras | le mot que l'examen attend |
/// | `*nuance*` | italique | une réserve, un mot étranger, un titre d'œuvre |
/// | `==l'essentiel==` | surligné | ce qu'on relit la veille, et rien d'autre |
/// | `$E = mc^2$` | formule | transposée par `FormulaRenderer`, comme sur les cartes |
///
/// Le balisage est **résolu à l'affichage**, jamais stocké dans un texte destiné aux
/// cartes : `plain(_:)` rend la même phrase sans ses marques, et c'est cette version qui
/// part au modèle. Un délimiteur seul ne casse rien : sans fermeture, il reste un
/// caractère comme un autre, ce qui est indispensable pour un cours de statistiques où
/// l'astérisque veut dire « significatif ».
enum SheetMarkup {
    struct Span: Equatable {
        var text: String
        var isBold: Bool = false
        var isItalic: Bool = false
        var isHighlighted: Bool = false
        /// Fragment mathématique, déjà transposé en Unicode.
        var isMath: Bool = false
    }

    private enum Marker {
        static let bold = "**"
        static let highlight = "=="
        static let italic = "*"
        static let math = "$"
    }

    /// Découpe un texte balisé en fragments homogènes.
    static func spans(_ source: String) -> [Span] {
        let characters = Array(source)
        var spans: [Span] = []
        var buffer = ""
        var bold = false
        var italic = false
        var highlighted = false
        var index = 0

        func flush() {
            guard !buffer.isEmpty else { return }
            spans.append(
                Span(text: buffer, isBold: bold, isItalic: italic, isHighlighted: highlighted)
            )
            buffer = ""
        }

        while index < characters.count {
            // Une formule est opaque : le balisage n'y entre pas, sinon `a^*` deviendrait
            // de l'italique au milieu d'une expression.
            if characters[index] == Character(Marker.math),
               let close = nextIndex(of: Marker.math, in: characters, from: index + 1) {
                let latex = String(characters[(index + 1)..<close])
                let rendered = FormulaRenderer.plain(latex)
                if !rendered.isEmpty {
                    flush()
                    spans.append(
                        Span(
                            text: rendered,
                            isBold: bold,
                            isItalic: italic,
                            isHighlighted: highlighted,
                            isMath: true
                        )
                    )
                }
                index = close + 1
                continue
            }

            if matches(Marker.bold, in: characters, at: index) {
                if bold {
                    flush()
                    bold = false
                    index += Marker.bold.count
                    continue
                }
                if nextIndex(of: Marker.bold, in: characters, from: index + Marker.bold.count) != nil {
                    flush()
                    bold = true
                    index += Marker.bold.count
                    continue
                }
            }

            if matches(Marker.highlight, in: characters, at: index) {
                if highlighted {
                    flush()
                    highlighted = false
                    index += Marker.highlight.count
                    continue
                }
                if nextIndex(of: Marker.highlight, in: characters, from: index + Marker.highlight.count) != nil {
                    flush()
                    highlighted = true
                    index += Marker.highlight.count
                    continue
                }
            }

            if characters[index] == Character(Marker.italic) {
                if italic {
                    flush()
                    italic = false
                    index += 1
                    continue
                }
                if closingItalic(in: characters, from: index + 1) != nil {
                    flush()
                    italic = true
                    index += 1
                    continue
                }
            }

            buffer.append(characters[index])
            index += 1
        }

        flush()
        return spans
    }

    /// Le même texte sans ses marques, formules transposées. C'est cette version qui part
    /// au modèle et qui sert de contexte aux cartes.
    static func plain(_ source: String) -> String {
        spans(source)
            .map(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Vrai si le texte porte au moins une marque exploitable. Sert aux tests et aux
    /// aperçus, pas au rendu.
    static func containsMarkup(_ source: String) -> Bool {
        spans(source).contains { $0.isBold || $0.isItalic || $0.isHighlighted || $0.isMath }
    }

    // MARK: - Balayage

    private static func matches(_ needle: String, in characters: [Character], at index: Int) -> Bool {
        let needleCharacters = Array(needle)
        guard index + needleCharacters.count <= characters.count else { return false }
        return Array(characters[index..<(index + needleCharacters.count)]) == needleCharacters
    }

    private static func nextIndex(of needle: String, in characters: [Character], from start: Int) -> Int? {
        guard start < characters.count else { return nil }
        var index = start
        while index < characters.count {
            if matches(needle, in: characters, at: index) { return index }
            index += 1
        }
        return nil
    }

    /// Fermeture d'une italique : une astérisque seule, jamais la moitié d'un `**`.
    private static func closingItalic(in characters: [Character], from start: Int) -> Int? {
        var index = start
        while index < characters.count {
            if characters[index] == Character(Marker.italic) {
                let isDouble = matches(Marker.bold, in: characters, at: index)
                if !isDouble { return index }
                index += Marker.bold.count
                continue
            }
            index += 1
        }
        return nil
    }
}
