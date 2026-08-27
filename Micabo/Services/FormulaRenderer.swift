import Foundation

/// Rendu des formules écrites en LaTeX dans les cartes.
///
/// Micabo n'embarque pas de moteur LaTeX : le système n'en fournit pas, et en ajouter un
/// pour trois symboles serait disproportionné. Les fragments délimités par `$…$` (ou
/// `$$…$$`) sont donc **transposés en Unicode** — exposants, indices, lettres grecques,
/// racines, fractions — puis affichés dans une italique à empattements.
///
/// Ce que ça couvre : les formules qu'on écrit sur une carte, `$E = mc^2$`,
/// `$\frac{1}{2}mv^2$`, `$H_2O$`, `$\Delta v = a \times t$`. Ce que ça ne couvre pas :
/// les matrices, les intégrales à bornes, les alignements sur plusieurs lignes. C'est
/// assumé — mieux vaut une formule lisible qu'un `\frac{}{}` affiché tel quel.
enum FormulaRenderer {
    struct Segment: Equatable {
        var text: String
        var isMath: Bool
    }

    static func containsFormula(_ source: String) -> Bool {
        segments(of: source).contains { $0.isMath }
    }

    /// Découpe un texte en fragments littéraux et mathématiques.
    /// Un `$` orphelin ne casse rien : le fragment reste du texte.
    static func segments(of source: String) -> [Segment] {
        let normalized = source.replacingOccurrences(of: "$$", with: "$")
        let pieces = normalized.components(separatedBy: "$")
        guard pieces.count > 1 else {
            return [Segment(text: source, isMath: false)]
        }

        // Un nombre pair de délimiteurs laisse un fragment ouvert : on le rend littéral.
        let hasOpenFragment = pieces.count % 2 == 0

        var segments: [Segment] = []
        for (index, piece) in pieces.enumerated() {
            let isLast = index == pieces.count - 1
            let isMath = index % 2 == 1 && !(isLast && hasOpenFragment)
            guard !piece.isEmpty else { continue }
            // Hors `$…$`, on transpose quand même les commandes : une carte générée écrit
            // souvent `1914 \rightarrow 1918` sans délimiteurs.
            segments.append(Segment(text: isMath ? plain(piece) : symbolsOnly(piece), isMath: isMath))
        }
        return segments.isEmpty ? [Segment(text: "", isMath: false)] : segments
    }

    /// Le même texte, formules transposées, sans mise en forme : pour les listes et les
    /// endroits où l'on ne peut pas composer plusieurs styles.
    static func stripped(_ source: String) -> String {
        segments(of: source).map(\.text).joined()
    }

    // MARK: - Transposition

    /// Les commandes seules, sans toucher aux `_` et `^` d'une phrase.
    static func symbolsOnly(_ source: String) -> String {
        replacingCommands(in: source)
    }

    /// Transpose un fragment LaTeX en Unicode lisible.
    static func plain(_ latex: String) -> String {
        var text = latex
        text = replacingFractions(in: text)
        text = replacingRoots(in: text)

        text = replacingCommands(in: text)

        text = replacingScripts(in: text, marker: "^", map: superscripts)
        text = replacingScripts(in: text, marker: "_", map: subscripts)
        text = strippingMarkup(in: text)

        return text
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// `\frac{a}{b}` devient `a/b`, et `(a+b)/(c)` quand les termes ne sont pas atomiques.
    private static func replacingFractions(in source: String) -> String {
        let characters = Array(source)
        var index = 0
        var output = ""

        while index < characters.count {
            if matches("\\frac", in: characters, at: index),
               let numerator = braceGroup(in: characters, from: index + 5),
               let denominator = braceGroup(in: characters, from: numerator.end) {
                let top = plain(numerator.content)
                let bottom = plain(denominator.content)
                output += "\(wrapped(top))/\(wrapped(bottom))"
                index = denominator.end
                continue
            }

            output.append(characters[index])
            index += 1
        }
        return output
    }

    /// `\sqrt{x}` devient `√x`, `√(x + 1)` si le contenu respire.
    private static func replacingRoots(in source: String) -> String {
        let characters = Array(source)
        var index = 0
        var output = ""

        while index < characters.count {
            if matches("\\sqrt", in: characters, at: index),
               let group = braceGroup(in: characters, from: index + 5) {
                output += "√\(wrapped(plain(group.content)))"
                index = group.end
                continue
            }

            output.append(characters[index])
            index += 1
        }
        return output
    }

    /// Remplace les commandes par leur symbole.
    ///
    /// L'espace qui suit une commande est un séparateur LaTeX, pas une espace typographique :
    /// `\Delta v` désigne la variable Δv. On ne l'absorbe que devant une variable, pour ne
    /// pas coller un opérateur à son voisin — `\alpha + 1` reste « α + 1 ».
    private static func replacingCommands(in source: String) -> String {
        let characters = Array(source)
        var index = 0
        var output = ""

        while index < characters.count {
            guard characters[index] == "\\", let match = command(in: characters, at: index) else {
                output.append(characters[index])
                index += 1
                continue
            }

            output += match.symbol
            index = match.end

            let followedByVariable = index + 1 < characters.count
                && characters[index] == " "
                && (characters[index + 1].isLetter || characters[index + 1].isNumber)

            if match.absorbsSpace, followedByVariable {
                index += 1
            }
        }
        return output
    }

    /// La plus longue commande qui correspond à cette position : « \int » ne doit pas être
    /// mangé par « \in ».
    private static func command(in characters: [Character], at index: Int) -> (symbol: String, end: Int, absorbsSpace: Bool)? {
        for (name, symbol) in sortedSymbols where matches(name, in: characters, at: index) {
            // Une commande qui donne une lettre nomme une variable (α, Δ, ℝ) ; les autres
            // sont des opérateurs ou des relations.
            let isLetter = symbol.count == 1 && (symbol.first?.isLetter ?? false)
            return (symbol, index + name.count, isLetter)
        }
        return nil
    }

    private static let sortedSymbols: [(key: String, value: String)] = symbols
        .sorted { $0.key.count > $1.key.count }
        .map { (key: $0.key, value: $0.value) }

    /// Exposants et indices : en Unicode quand tous les caractères existent, sinon on
    /// garde le marqueur et on met des parenthèses — c'est encore lisible.
    private static func replacingScripts(in source: String, marker: Character, map: [Character: Character]) -> String {
        let characters = Array(source)
        var index = 0
        var output = ""

        while index < characters.count {
            guard characters[index] == marker, index + 1 < characters.count else {
                output.append(characters[index])
                index += 1
                continue
            }

            let content: String
            let next: Int
            if characters[index + 1] == "{", let group = braceGroup(in: characters, from: index + 1) {
                content = group.content
                next = group.end
            } else {
                content = String(characters[index + 1])
                next = index + 2
            }

            if let converted = converted(content, using: map) {
                output += converted
            } else {
                output += "\(marker)(\(content))"
            }
            index = next
        }
        return output
    }

    private static func converted(_ content: String, using map: [Character: Character]) -> String? {
        var result = ""
        for character in content {
            guard let replacement = map[character] else { return nil }
            result.append(replacement)
        }
        return result.isEmpty ? nil : result
    }

    /// Retire ce qui reste de balisage : accolades, commandes inconnues, espaces LaTeX.
    private static func strippingMarkup(in source: String) -> String {
        var text = source
        for noise in ["\\left", "\\right", "\\displaystyle", "\\text", "\\mathrm", "\\,", "\\;", "\\!", "\\ "] {
            text = text.replacingOccurrences(of: noise, with: noise == "\\," || noise == "\\;" || noise == "\\ " ? " " : "")
        }
        text = text.replacingOccurrences(of: "{", with: "")
        text = text.replacingOccurrences(of: "}", with: "")
        text = text.replacingOccurrences(of: "\\", with: "")
        return text
    }

    // MARK: - Petits outils de balayage

    private static func matches(_ needle: String, in characters: [Character], at index: Int) -> Bool {
        let needleCharacters = Array(needle)
        guard index + needleCharacters.count <= characters.count else { return false }
        return Array(characters[index..<(index + needleCharacters.count)]) == needleCharacters
    }

    /// Contenu d'un groupe `{…}` commençant à `index`, et l'index juste après l'accolade
    /// fermante. Gère l'imbrication.
    private static func braceGroup(in characters: [Character], from index: Int) -> (content: String, end: Int)? {
        guard index < characters.count, characters[index] == "{" else { return nil }

        var depth = 0
        var content = ""
        var cursor = index

        while cursor < characters.count {
            let character = characters[cursor]
            if character == "{" {
                depth += 1
                if depth == 1 {
                    cursor += 1
                    continue
                }
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return (content, cursor + 1)
                }
            }
            content.append(character)
            cursor += 1
        }
        return nil
    }

    /// Parenthèse un terme composé, laisse un terme atomique tranquille.
    private static func wrapped(_ term: String) -> String {
        let needsParentheses = term.count > 1 && term.contains(where: { " +-*/=".contains($0) })
        return needsParentheses ? "(\(term))" : term
    }

    // MARK: - Tables

    static let symbols: [String: String] = [
        "\\times": "×", "\\div": "÷", "\\pm": "±", "\\mp": "∓", "\\cdot": "·",
        "\\leq": "≤", "\\geq": "≥", "\\neq": "≠", "\\approx": "≈", "\\equiv": "≡",
        "\\propto": "∝", "\\sim": "∼", "\\infty": "∞", "\\degree": "°", "\\circ": "∘",
        "\\rightarrow": "→", "\\to": "→", "\\leftarrow": "←", "\\Rightarrow": "⇒",
        "\\Leftrightarrow": "⇔", "\\iff": "⇔", "\\mapsto": "↦",
        "\\sum": "∑", "\\prod": "∏", "\\int": "∫", "\\partial": "∂", "\\nabla": "∇",
        "\\in": "∈", "\\notin": "∉", "\\forall": "∀", "\\exists": "∃",
        "\\cup": "∪", "\\cap": "∩", "\\subset": "⊂", "\\supset": "⊃", "\\emptyset": "∅",
        "\\ldots": "…", "\\dots": "…", "\\cdots": "⋯", "\\angle": "∠", "\\perp": "⊥",
        "\\alpha": "α", "\\beta": "β", "\\gamma": "γ", "\\delta": "δ", "\\epsilon": "ε",
        "\\varepsilon": "ε", "\\zeta": "ζ", "\\eta": "η", "\\theta": "θ", "\\iota": "ι",
        "\\kappa": "κ", "\\lambda": "λ", "\\mu": "μ", "\\nu": "ν", "\\xi": "ξ",
        "\\pi": "π", "\\rho": "ρ", "\\sigma": "σ", "\\tau": "τ", "\\upsilon": "υ",
        "\\phi": "φ", "\\varphi": "φ", "\\chi": "χ", "\\psi": "ψ", "\\omega": "ω",
        "\\Gamma": "Γ", "\\Delta": "Δ", "\\Theta": "Θ", "\\Lambda": "Λ", "\\Xi": "Ξ",
        "\\Pi": "Π", "\\Sigma": "Σ", "\\Phi": "Φ", "\\Psi": "Ψ", "\\Omega": "Ω",
        "\\mathbb{R}": "ℝ", "\\mathbb{N}": "ℕ", "\\mathbb{Z}": "ℤ", "\\mathbb{Q}": "ℚ",
        "\\mathbb{C}": "ℂ"
    ]

    static let superscripts: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷",
        "8": "⁸", "9": "⁹", "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
        "a": "ᵃ", "b": "ᵇ", "c": "ᶜ", "d": "ᵈ", "e": "ᵉ", "f": "ᶠ", "g": "ᵍ", "h": "ʰ",
        "i": "ⁱ", "j": "ʲ", "k": "ᵏ", "l": "ˡ", "m": "ᵐ", "n": "ⁿ", "o": "ᵒ", "p": "ᵖ",
        "r": "ʳ", "s": "ˢ", "t": "ᵗ", "u": "ᵘ", "v": "ᵛ", "w": "ʷ", "x": "ˣ", "y": "ʸ",
        "z": "ᶻ"
    ]

    static let subscripts: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇",
        "8": "₈", "9": "₉", "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "l": "ₗ", "m": "ₘ",
        "n": "ₙ", "o": "ₒ", "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ", "v": "ᵥ",
        "x": "ₓ"
    ]
}
