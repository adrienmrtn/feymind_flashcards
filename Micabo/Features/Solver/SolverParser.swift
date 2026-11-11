import Foundation

// MARK: - Ce que Mika rend

/// Une étape de la solution : un titre court, et son explication (texte balisé, formules entre
/// `$…$` ou seules sur leur ligne entre `$$…$$`).
struct SolverStep: Equatable, Codable {
    var title: String
    var body: String
}

/// **La solution d'un exercice**, lue dans la réponse de Mika.
struct SolverSolution: Equatable {
    var subject: SolverSubject?
    var steps: [SolverStep]
    var answer: String?
    /// Faux quand la réponse n'avait pas les balises demandées et qu'on a découpé ses
    /// paragraphes : l'écran l'affiche pareil, mais les statistiques le comptent.
    var isStructured: Bool

    /// La solution en texte simple, pour la renvoyer à Mika avec la question suivante
    /// (« Je ne comprends pas cette étape », la discussion de la matière).
    func transcript(answerLabel: String) -> String {
        var lines: [String] = []
        for (index, step) in steps.enumerated() {
            let head = step.title.isEmpty ? "\(index + 1)." : "\(index + 1). \(step.title)"
            lines.append(step.body.isEmpty ? head : "\(head)\n\(step.body)")
        }
        if let answer { lines.append("\(answerLabel) : \(answer)") }
        return lines.joined(separator: "\n\n")
    }
}

/// Un morceau du corps d'une étape : du texte, ou une formule posée seule.
enum SolverBlock: Equatable {
    case text(String)
    case formula(String)
}

// MARK: - Le parseur

/// **Lire la réponse de Mika sans jamais rien perdre.**
///
/// On demande des balises (`[SUBJECT]`, `[STEP]`, `[ANSWER]`) plutôt que du JSON : la réponse
/// voyage déjà **dans** le JSON de `mika-chat`, et un JSON dans une chaîne JSON est le premier
/// endroit où un modèle se trompe d'échappement. Une balise mal écrite (`**[STEP 2]**`,
/// `[step]:`, `[ÉTAPE]`) se lit quand même ; une réponse sans balises est découpée en
/// paragraphes ; et si rien ne se découpe, `parse` rend `nil` et l'écran affiche le texte tel
/// quel. L'élève voit toujours ce que Mika a dit.
enum SolverParser {
    enum Tag: String {
        case subject
        case step
        case answer
        case exercise
        case right
        case wrong
    }

    /// Les mots de balise reconnus, dans les langues où un modèle pourrait les traduire.
    private static let aliases: [String: Tag] = [
        "subject": .subject, "matiere": .subject,
        "step": .step, "etape": .step, "schritt": .step, "paso": .step, "adim": .step, "passo": .step,
        "answer": .answer, "reponse": .answer, "antwort": .answer, "respuesta": .answer, "cevap": .answer,
        "risposta": .answer, "final answer": .answer, "result": .answer,
        "exercise": .exercise, "exercice": .exercise, "aufgabe": .exercise, "ejercicio": .exercise,
        "right": .right, "correct": .right, "juste": .right, "richtig": .right,
        "wrong": .wrong, "incorrect": .wrong, "faux": .wrong, "falsch": .wrong,
    ]

    /// `[STEP]`, `[Step 2]`, `**[ANSWER]**`, `[ÉTAPE 1] :`. Le mot de la balise est capturé.
    private static let tagPattern = try! NSRegularExpression(
        pattern: #"\*{0,2}\[\s*([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ ]{0,15}?)\s*\d*\s*\]\*{0,2}\s*:?[ \t]*"#
    )

    // MARK: Les sections

    /// Les sections balisées d'un texte, dans l'ordre. Le texte avant la première balise est
    /// ignoré (une phrase d'introduction que le modèle aurait ajoutée).
    static func sections(of raw: String) -> [(tag: Tag, text: String)] {
        let text = repaired(raw)
        let range = NSRange(text.startIndex..., in: text)
        var marks: [(tag: Tag, start: String.Index, end: String.Index)] = []
        for match in tagPattern.matches(in: text, range: range) {
            guard let whole = Range(match.range, in: text),
                  let word = Range(match.range(at: 1), in: text) else { continue }
            let key = SolverSubjectGuess.fold(String(text[word])).trimmingCharacters(in: .whitespaces)
            guard let tag = aliases[key] else { continue }
            marks.append((tag, whole.lowerBound, whole.upperBound))
        }
        var sections: [(tag: Tag, text: String)] = []
        for (index, mark) in marks.enumerated() {
            let end = index + 1 < marks.count ? marks[index + 1].start : text.endIndex
            let body = String(text[mark.end..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append((mark.tag, body))
        }
        return sections
    }

    // MARK: La solution

    static func parse(_ raw: String) -> SolverSolution? {
        let sections = Self.sections(of: raw)
        var subject: SolverSubject?
        var steps: [SolverStep] = []
        var answer: String?
        for section in sections {
            switch section.tag {
            case .subject:
                subject = SolverSubject(modelWord: section.text.components(separatedBy: .newlines).first ?? "")
            case .step:
                if let step = Self.step(from: section.text) { steps.append(step) }
            case .answer:
                let clean = section.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty { answer = clean }
            case .exercise, .right, .wrong:
                continue
            }
        }
        if !steps.isEmpty {
            return SolverSolution(subject: subject, steps: steps, answer: answer, isStructured: true)
        }
        if answer != nil {
            // Une réponse sans étapes : l'explication est ce qui précède la première balise.
            let before = beforeFirstTag(raw)
            let fallback = paragraphs(before).map { SolverStep(title: "", body: $0) }
            return SolverSolution(subject: subject, steps: fallback, answer: answer, isStructured: !fallback.isEmpty)
        }
        return unstructured(raw)
    }

    /// Une étape : la première ligne est son titre quand il y a de quoi expliquer dessous, ou
    /// quand elle porte un « titre : explication » court. Sinon, l'étape n'a pas de titre.
    static func step(from text: String) -> SolverStep? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        var lines = clean.components(separatedBy: "\n")
        let first = lines.removeFirst().trimmingCharacters(in: .whitespaces)
        let rest = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let looksLikeTitle = first.count <= 40 || (first.count <= 80 && !first.hasSuffix("."))
        if !rest.isEmpty, looksLikeTitle, !first.hasPrefix("$") {
            return SolverStep(title: unbold(first), body: rest)
        }
        // « Isoler x : on retire 3 des deux côtés. »
        if let colon = first.range(of: " : ") ?? first.range(of: ": "),
           first.distance(from: first.startIndex, to: colon.lowerBound) <= 48,
           !first[..<colon.lowerBound].contains("$") {
            let title = String(first[..<colon.lowerBound])
            let body = String(first[colon.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !body.isEmpty {
                return SolverStep(title: unbold(title), body: [body, rest].filter { !$0.isEmpty }.joined(separator: "\n"))
            }
        }
        return SolverStep(title: "", body: clean)
    }

    /// Sans balises : les étapes numérotées (« 1. », « 2) », « Étape 3 : »), sinon les
    /// paragraphes. Un seul paragraphe ne fait pas une solution pas à pas : `nil`, et l'écran
    /// affiche le texte.
    static func unstructured(_ raw: String) -> SolverSolution? {
        let text = untagged(raw)
        let numbered = numberedSteps(text)
        if numbered.count >= 2 {
            return SolverSolution(subject: nil, steps: numbered, answer: nil, isStructured: false)
        }
        let blocks = paragraphs(text)
        guard blocks.count >= 2 else { return nil }
        return SolverSolution(subject: nil, steps: blocks.map { step(from: $0) ?? SolverStep(title: "", body: $0) }, answer: nil, isStructured: false)
    }

    private static let numberedLine = try! NSRegularExpression(
        pattern: #"^\s*(?:\*\*)?(?:\d{1,2}[.)]|[A-Za-zÀ-ÿ]{3,12}\s\d{1,2}\s?[:.)])(?:\*\*)?\s+"#
    )

    static func numberedSteps(_ text: String) -> [SolverStep] {
        var steps: [String] = []
        for line in text.components(separatedBy: "\n") {
            let range = NSRange(line.startIndex..., in: line)
            if let match = numberedLine.firstMatch(in: line, range: range), let marker = Range(match.range, in: line) {
                steps.append(String(line[marker.upperBound...]))
            } else if !steps.isEmpty {
                steps[steps.count - 1] += "\n" + line
            }
        }
        return steps.compactMap { step(from: $0) }
    }

    static func paragraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Le texte sans ses balises, pour l'afficher tel quel. Un crochet qui n'est pas une
    /// balise (`[a, b]`, `[x]`) reste.
    static func untagged(_ raw: String) -> String {
        let text = repaired(raw)
        var out = ""
        var cursor = text.startIndex
        for match in matches(in: text) where match.isTag {
            out += text[cursor..<match.range.lowerBound]
            cursor = match.range.upperBound
        }
        out += text[cursor...]
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ce qui précède la première balise reconnue.
    static func beforeFirstTag(_ raw: String) -> String {
        let text = repaired(raw)
        guard let first = matches(in: text).first(where: { $0.isTag }) else { return text }
        return String(text[..<first.range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Chaque crochet qui ressemble à une balise, et s'il en est une.
    private static func matches(in text: String) -> [(range: Range<String.Index>, isTag: Bool)] {
        let range = NSRange(text.startIndex..., in: text)
        return tagPattern.matches(in: text, range: range).compactMap { match -> (range: Range<String.Index>, isTag: Bool)? in
            guard let whole = Range(match.range, in: text), let word = Range(match.range(at: 1), in: text) else { return nil }
            let key = SolverSubjectGuess.fold(String(text[word])).trimmingCharacters(in: .whitespaces)
            return (whole, aliases[key] != nil)
        }
    }

    private static func unbold(_ text: String) -> String {
        var out = text.trimmingCharacters(in: .whitespaces)
        if out.hasPrefix("**"), out.hasSuffix("**"), out.count > 4 {
            out = String(out.dropFirst(2).dropLast(2))
        }
        if out.hasSuffix(":") { out = String(out.dropLast()).trimmingCharacters(in: .whitespaces) }
        return out
    }

    // MARK: L'entraînement

    /// L'exercice d'entraînement : `[EXERCISE]` et `[ANSWER]`. Sans balise, tout le texte est
    /// l'énoncé, et la réponse attendue manque (Mika corrigera quand même).
    static func practice(_ raw: String) -> SolverPractice? {
        let sections = Self.sections(of: raw)
        let exercise = sections.first { $0.tag == .exercise }?.text
        let expected = sections.first { $0.tag == .answer }?.text
        if let exercise, !exercise.isEmpty {
            return SolverPractice(exercise: exercise, expected: expected?.nilIfBlank)
        }
        let plain = untagged(raw)
        guard !plain.isEmpty else { return nil }
        return SolverPractice(exercise: plain, expected: nil)
    }

    /// La correction : `[RIGHT]` ou `[WRONG]`, puis l'explication.
    static func verdict(_ raw: String) -> (verdict: SolverVerdict?, text: String) {
        let sections = Self.sections(of: raw)
        if let first = sections.first(where: { $0.tag == .right || $0.tag == .wrong }) {
            let verdict: SolverVerdict = first.tag == .right ? .right : .wrong
            let text = untagged(raw)
            return (verdict, text)
        }
        return (nil, untagged(raw))
    }

    // MARK: Les formules

    /// Les échappées perdues en route. Un modèle qui écrit `\frac` dans du JSON sans doubler
    /// l'antislash fait lire au décodeur un saut de page suivi de « rac » ; `\times` devient une
    /// tabulation et « imes », `\beta` un retour arrière. On remet l'antislash.
    static func repaired(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\u{0C}", with: "\\f")
        text = text.replacingOccurrences(of: "\u{08}", with: "\\b")
        for command in ["times", "theta", "tau", "tan", "text", "tfrac", "triangle"] {
            text = text.replacingOccurrences(of: "\t" + command, with: "\\" + command)
        }
        for command in ["rightarrow", "rho", "right"] {
            text = text.replacingOccurrences(of: "\r" + command, with: "\\" + command)
        }
        for command in ["neq", "nabla", "notin", "nexists"] {
            text = text.replacingOccurrences(of: "\n" + command, with: "\\" + command)
        }
        text = text.replacingOccurrences(of: "\r", with: "\n")
        // Les délimiteurs de LaTeX que la fiche ne lit pas : `\( … \)` et `\[ … \]`.
        text = text.replacingOccurrences(of: "\\(", with: "$").replacingOccurrences(of: "\\)", with: "$")
        text = text.replacingOccurrences(of: "\\[", with: "$$").replacingOccurrences(of: "\\]", with: "$$")
        // Un bloc de code autour de la réponse.
        text = text.replacingOccurrences(of: "```", with: "")
        return text
    }

    /// **Le corps d'une étape, découpé pour l'écran** : une formule seule sur sa ligne
    /// (`$$…$$`, ou `$…$` sans rien autour) est posée à part, composée par le moteur ; le
    /// reste est du texte, ses formules transposées dans la phrase. Un `$$` ouvert sur une
    /// ligne et fermé plus bas forme une seule formule.
    static func blocks(of body: String) -> [SolverBlock] {
        var blocks: [SolverBlock] = []
        var paragraph: [String] = []
        var openFormula: [String]?

        func flushText() {
            let joined = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { blocks.append(.text(joined)) }
            paragraph = []
        }

        for rawLine in repaired(body).components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if var open = openFormula {
                if let close = line.range(of: "$$") {
                    open.append(String(line[..<close.lowerBound]))
                    let latex = open.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    if !latex.isEmpty { blocks.append(.formula(latex)) }
                    openFormula = nil
                    let after = String(line[close.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !after.isEmpty { paragraph.append(after) }
                } else {
                    open.append(line)
                    openFormula = open
                }
                continue
            }
            if let formula = MathTypesetter.soleFormula(in: line) {
                flushText()
                blocks.append(.formula(formula))
                continue
            }
            if line == "$$" || (line.hasPrefix("$$") && line.components(separatedBy: "$$").count == 2) {
                flushText()
                openFormula = [String(line.dropFirst(2))]
                continue
            }
            if line.isEmpty {
                flushText()
            } else {
                paragraph.append(line)
            }
        }
        if let open = openFormula {
            // Un `$$` jamais refermé : le texte reste du texte, plutôt qu'une formule cassée.
            paragraph.append("$$" + open.joined(separator: " "))
        }
        flushText()
        return blocks
    }
}
