package com.micabo.app.ui.text

/**
 * **Les formules LaTeX, transposées en Unicode** — exposants, indices, lettres grecques,
 * racines, fractions —, comme `FormulaRenderer.swift` sur iPhone. Pas de moteur LaTeX : mieux
 * vaut une formule lisible qu'un `\frac{}{}` affiché tel quel.
 */
object FormulaRenderer {
    data class Segment(val text: String, val isMath: Boolean)

    /** Découpe un texte en fragments littéraux et mathématiques. Un `$` orphelin reste du texte. */
    fun segments(source: String): List<Segment> {
        val normalized = source.replace("$$", "$")
        val pieces = normalized.split("$")
        if (pieces.size <= 1) return listOf(Segment(symbolsOnly(source), false))
        val hasOpenFragment = pieces.size % 2 == 0
        val out = mutableListOf<Segment>()
        pieces.forEachIndexed { index, piece ->
            val isLast = index == pieces.lastIndex
            val isMath = index % 2 == 1 && !(isLast && hasOpenFragment)
            if (piece.isEmpty()) return@forEachIndexed
            out.add(Segment(if (isMath) plain(piece) else symbolsOnly(piece), isMath))
        }
        return out.ifEmpty { listOf(Segment("", false)) }
    }

    fun stripped(source: String): String = segments(source).joinToString("") { it.text }

    fun symbolsOnly(source: String): String = replacingCommands(replacingLabelledArrows(source))

    fun plain(latex: String): String {
        var text = replacingLabelledArrows(latex)
        text = replacingFractions(text)
        text = replacingRoots(text)
        text = replacingCommands(text)
        text = strippingStyles(text)
        text = replacingScripts(text, '^', SUPERSCRIPTS)
        text = replacingScripts(text, '_', SUBSCRIPTS)
        text = strippingMarkup(text)
        return text.replace("  ", " ").trim()
    }

    /**
     * Les flèches étiquetées d'amsmath, l'antislash facultatif : une leçon écrite avant la
     * réparation des échappées l'a parfois perdu (« xrightarrow{Lumière} »). Jumeau de
     * `SheetText.labelledArrow` sur iPhone et de `LABELLED_ARROW` côté serveur.
     */
    val LABELLED_ARROW = Regex("\\\\?x(right|left)arrow\\s*(?:\\[[^\\]]*\\])?\\s*\\{([^{}]*)\\}")

    /** `\xrightarrow{Lumière}` devient `→ (Lumière)` : on lisait « xrightarrowLumière ». */
    fun replacingLabelledArrows(source: String): String {
        if (!source.contains("arrow")) return source
        return LABELLED_ARROW.replace(source) { match ->
            val arrow = if (match.groupValues[1] == "right") "→" else "←"
            val label = match.groupValues[2].trim()
            if (label.isEmpty()) arrow else "$arrow ($label)"
        }
    }

    private fun replacingFractions(source: String): String {
        val out = StringBuilder()
        var index = 0
        while (index < source.length) {
            if (source.startsWith("\\frac", index) || source.startsWith("\\dfrac", index) || source.startsWith("\\tfrac", index)) {
                val start = source.indexOf('{', index)
                val numerator = if (start == index + 5 || start == index + 6) braceGroup(source, start) else null
                val denominator = numerator?.let { braceGroup(source, it.second) }
                if (numerator != null && denominator != null) {
                    out.append(wrapped(plain(numerator.first))).append('/').append(wrapped(plain(denominator.first)))
                    index = denominator.second
                    continue
                }
            }
            out.append(source[index])
            index += 1
        }
        return out.toString()
    }

    private fun replacingRoots(source: String): String {
        val out = StringBuilder()
        var index = 0
        while (index < source.length) {
            if (source.startsWith("\\sqrt", index)) {
                // `\sqrt[3]{x}` devient ³√x : l'indice de la racine passe en exposant devant.
                val close = if (source.getOrNull(index + 5) == '[') source.indexOf(']', index + 5) else -1
                val degree = if (close > 0) source.substring(index + 6, close) else ""
                val group = braceGroup(source, if (close > 0) close + 1 else index + 5)
                if (group != null) {
                    if (degree.isNotBlank()) out.append(converted(degree.trim(), SUPERSCRIPTS) ?: "(${degree.trim()})")
                    out.append('√').append(wrapped(plain(group.first)))
                    index = group.second
                    continue
                }
            }
            out.append(source[index])
            index += 1
        }
        return out.toString()
    }

    private fun replacingCommands(source: String): String {
        val out = StringBuilder()
        var index = 0
        while (index < source.length) {
            if (source[index] != '\\') {
                out.append(source[index])
                index += 1
                continue
            }
            val match = SORTED.firstOrNull { (name, _) ->
                // Une commande s'arrête à la première lettre qui ne lui appartient pas :
                // « \left » n'est pas « \le » suivi de « ft ».
                source.startsWith(name, index) &&
                    !(name.last().isLetter() && index + name.length < source.length && source[index + name.length].isLetter())
            }
            if (match == null) {
                out.append(source[index])
                index += 1
                continue
            }
            out.append(match.second)
            index += match.first.length
            val isLetter = match.second.length == 1 && match.second[0].isLetter()
            val followedByVariable = index + 1 < source.length && source[index] == ' ' &&
                (source[index + 1].isLetterOrDigit())
            if (isLetter && followedByVariable) index += 1
        }
        return out.toString()
    }

    private fun replacingScripts(source: String, marker: Char, map: Map<Char, Char>): String {
        val out = StringBuilder()
        var index = 0
        while (index < source.length) {
            if (source[index] != marker || index + 1 >= source.length) {
                out.append(source[index])
                index += 1
                continue
            }
            val content: String
            val next: Int
            val group = if (source[index + 1] == '{') braceGroup(source, index + 1) else null
            if (group != null) {
                content = group.first
                next = group.second
            } else {
                content = source[index + 1].toString()
                next = index + 2
            }
            val converted = converted(content, map)
            if (converted != null) out.append(converted) else out.append(marker).append('(').append(content).append(')')
            index = next
        }
        return out.toString()
    }

    private fun converted(content: String, map: Map<Char, Char>): String? {
        val out = StringBuilder()
        // Les accolades d'un `\text{max}` déjà retiré ne comptent pas : v_{\text{max}} donne vₘₐₓ.
        for (character in content) {
            if (character == '{' || character == '}') continue
            out.append(map[character] ?: return null)
        }
        return out.toString().ifEmpty { null }
    }

    /**
     * Les commandes de style (`\text`, `\mathrm`, `\vec`…) disparaissent avant les exposants et
     * les indices : leur contenu s'y transpose alors comme le reste. Les commandes à symbole
     * (`\leftarrow`…) ont déjà été remplacées.
     */
    private fun strippingStyles(source: String): String {
        var text = source
        for (style in STYLES) text = text.replace(style, "")
        return text
    }

    private val STYLES = listOf(
        "\\operatorname", "\\displaystyle", "\\overrightarrow", "\\overline", "\\mathrm", "\\mathbf",
        "\\mathit", "\\text", "\\vec", "\\hat", "\\bar",
    )

    private fun strippingMarkup(source: String): String {
        var text = source
        for (noise in listOf("\\left", "\\right", "\\displaystyle", "\\text", "\\mathrm", "\\mathbf", "\\operatorname", "\\,", "\\;", "\\!", "\\ ")) {
            text = text.replace(noise, if (noise == "\\," || noise == "\\;" || noise == "\\ ") " " else "")
        }
        return text.replace("{", "").replace("}", "").replace("\\", "")
    }

    /** Le contenu d'un groupe `{…}` qui commence à `index`, et l'index juste après. */
    private fun braceGroup(source: String, index: Int): Pair<String, Int>? {
        if (index !in source.indices || source[index] != '{') return null
        var depth = 0
        val content = StringBuilder()
        var cursor = index
        while (cursor < source.length) {
            val character = source[cursor]
            if (character == '{') {
                depth += 1
                if (depth == 1) {
                    cursor += 1
                    continue
                }
            } else if (character == '}') {
                depth -= 1
                if (depth == 0) return content.toString() to cursor + 1
            }
            content.append(character)
            cursor += 1
        }
        return null
    }

    private fun wrapped(term: String): String =
        if (term.length > 1 && term.any { it in " +-*/=" }) "($term)" else term

    private val SYMBOLS: Map<String, String> = mapOf(
        "\\times" to "×", "\\div" to "÷", "\\pm" to "±", "\\mp" to "∓", "\\cdot" to "·",
        "\\leq" to "≤", "\\geq" to "≥", "\\le" to "≤", "\\ge" to "≥", "\\neq" to "≠", "\\ne" to "≠",
        "\\approx" to "≈", "\\equiv" to "≡",
        "\\propto" to "∝", "\\sim" to "∼", "\\infty" to "∞", "\\degree" to "°", "\\circ" to "∘",
        "\\rightarrow" to "→", "\\to" to "→", "\\leftarrow" to "←", "\\Rightarrow" to "⇒",
        "\\Leftrightarrow" to "⇔", "\\iff" to "⇔", "\\mapsto" to "↦", "\\rightleftharpoons" to "⇌",
        "\\longrightarrow" to "⟶", "\\implies" to "⇒",
        "\\sum" to "∑", "\\prod" to "∏", "\\int" to "∫", "\\partial" to "∂", "\\nabla" to "∇",
        "\\in" to "∈", "\\notin" to "∉", "\\forall" to "∀", "\\exists" to "∃",
        "\\cup" to "∪", "\\cap" to "∩", "\\subset" to "⊂", "\\supset" to "⊃", "\\emptyset" to "∅",
        "\\ldots" to "…", "\\dots" to "…", "\\cdots" to "⋯", "\\angle" to "∠", "\\perp" to "⊥",
        "\\parallel" to "∥", "\\%" to "%", "\\lim" to "lim", "\\log" to "log", "\\ln" to "ln",
        "\\sin" to "sin", "\\cos" to "cos", "\\tan" to "tan", "\\exp" to "exp",
        "\\alpha" to "α", "\\beta" to "β", "\\gamma" to "γ", "\\delta" to "δ", "\\epsilon" to "ε",
        "\\varepsilon" to "ε", "\\zeta" to "ζ", "\\eta" to "η", "\\theta" to "θ", "\\iota" to "ι",
        "\\kappa" to "κ", "\\lambda" to "λ", "\\mu" to "μ", "\\nu" to "ν", "\\xi" to "ξ",
        "\\pi" to "π", "\\rho" to "ρ", "\\sigma" to "σ", "\\tau" to "τ", "\\upsilon" to "υ",
        "\\phi" to "φ", "\\varphi" to "φ", "\\chi" to "χ", "\\psi" to "ψ", "\\omega" to "ω",
        "\\Gamma" to "Γ", "\\Delta" to "Δ", "\\Theta" to "Θ", "\\Lambda" to "Λ", "\\Xi" to "Ξ",
        "\\Pi" to "Π", "\\Sigma" to "Σ", "\\Phi" to "Φ", "\\Psi" to "Ψ", "\\Omega" to "Ω",
        "\\mathbb{R}" to "ℝ", "\\mathbb{N}" to "ℕ", "\\mathbb{Z}" to "ℤ", "\\mathbb{Q}" to "ℚ",
        "\\mathbb{C}" to "ℂ",
    )

    private val SORTED: List<Pair<String, String>> = SYMBOLS.entries
        .sortedByDescending { it.key.length }
        .map { it.key to it.value }

    private val SUPERSCRIPTS: Map<Char, Char> = mapOf(
        '0' to '⁰', '1' to '¹', '2' to '²', '3' to '³', '4' to '⁴', '5' to '⁵', '6' to '⁶', '7' to '⁷',
        '8' to '⁸', '9' to '⁹', '+' to '⁺', '-' to '⁻', '=' to '⁼', '(' to '⁽', ')' to '⁾',
        'a' to 'ᵃ', 'b' to 'ᵇ', 'c' to 'ᶜ', 'd' to 'ᵈ', 'e' to 'ᵉ', 'f' to 'ᶠ', 'g' to 'ᵍ', 'h' to 'ʰ',
        'i' to 'ⁱ', 'j' to 'ʲ', 'k' to 'ᵏ', 'l' to 'ˡ', 'm' to 'ᵐ', 'n' to 'ⁿ', 'o' to 'ᵒ', 'p' to 'ᵖ',
        'r' to 'ʳ', 's' to 'ˢ', 't' to 'ᵗ', 'u' to 'ᵘ', 'v' to 'ᵛ', 'w' to 'ʷ', 'x' to 'ˣ', 'y' to 'ʸ',
        'z' to 'ᶻ', '−' to '⁻',
    )

    private val SUBSCRIPTS: Map<Char, Char> = mapOf(
        '0' to '₀', '1' to '₁', '2' to '₂', '3' to '₃', '4' to '₄', '5' to '₅', '6' to '₆', '7' to '₇',
        '8' to '₈', '9' to '₉', '+' to '₊', '-' to '₋', '=' to '₌', '(' to '₍', ')' to '₎',
        'a' to 'ₐ', 'e' to 'ₑ', 'h' to 'ₕ', 'i' to 'ᵢ', 'j' to 'ⱼ', 'k' to 'ₖ', 'l' to 'ₗ', 'm' to 'ₘ',
        'n' to 'ₙ', 'o' to 'ₒ', 'p' to 'ₚ', 'r' to 'ᵣ', 's' to 'ₛ', 't' to 'ₜ', 'u' to 'ᵤ', 'v' to 'ᵥ',
        'x' to 'ₓ',
    )
}
