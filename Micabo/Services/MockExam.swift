import Foundation

/// **La copie d'examen blanc, telle que le serveur et le site la lisent.**
///
/// C'est la même copie que sur le site : vingt questions posées d'un coup, aucune réponse
/// avant la remise, et rien à cocher soi-même. Les questions **fermées** - QCM, vrai ou faux,
/// mot caché - se corrigent ici, à la comparaison, sans modèle. Les questions **Feynman** -
/// « explique ceci comme à quelqu'un qui ne l'a jamais vu » - se répondent à voix haute et se
/// corrigent par le modèle, sur le serveur.
///
/// Le format est celui de `mock_sessions.questions` : le téléphone et le site écrivent et
/// lisent les mêmes lignes, donc un blanc commencé sur l'un se relit sur l'autre. Ce fichier
/// est le pendant de `packages/core/src/srs/mock-paper.ts`, et chaque règle y renvoie.
enum MockQuestion: Identifiable, Equatable, Codable {
    case choice(id: String, prompt: String, choices: [String], answerIndex: Int, why: String)
    case trueFalse(id: String, prompt: String, answer: Bool, why: String)
    case gap(id: String, prompt: String, answer: String, accepts: [String], why: String)
    case feynman(id: String, prompt: String, expected: String)

    /// Graphie unique du trou, la même que pour les cartes et que sur le site.
    static let gapMark = "…"

    var id: String {
        switch self {
        case .choice(let id, _, _, _, _), .trueFalse(let id, _, _, _), .gap(let id, _, _, _, _), .feynman(let id, _, _):
            id
        }
    }

    var prompt: String {
        switch self {
        case .choice(_, let prompt, _, _, _), .trueFalse(_, let prompt, _, _), .gap(_, let prompt, _, _, _), .feynman(_, let prompt, _):
            prompt
        }
    }

    /// Fermée : se corrige à la comparaison. Le reste est une explication orale.
    var isClosed: Bool {
        if case .feynman = self { return false }
        return true
    }

    /// Ce que la correction a à dire sur une question fermée.
    var why: String? {
        switch self {
        case .choice(_, _, _, _, let why), .trueFalse(_, _, _, let why), .gap(_, _, _, _, let why): why
        case .feynman: nil
        }
    }

    /// Ce qu'une bonne explication contient. Sert au modèle, jamais montré avant la remise.
    var expected: String? {
        if case .feynman(_, _, let expected) = self { return expected }
        return nil
    }

    var kindName: String {
        switch self {
        case .choice: "choice"
        case .trueFalse: "truefalse"
        case .gap: "gap"
        case .feynman: "feynman"
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case kind, id, prompt, choices, answerIndex, why, answer, accepts, expected
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        let id = try container.decode(String.self, forKey: .id)
        let prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        let why = try container.decodeIfPresent(String.self, forKey: .why) ?? ""

        switch kind {
        case "choice":
            self = .choice(
                id: id,
                prompt: prompt,
                choices: try container.decodeIfPresent([String].self, forKey: .choices) ?? [],
                answerIndex: try container.decodeIfPresent(Int.self, forKey: .answerIndex) ?? 0,
                why: why
            )
        case "truefalse":
            self = .trueFalse(
                id: id,
                prompt: prompt,
                answer: try container.decodeIfPresent(Bool.self, forKey: .answer) ?? false,
                why: why
            )
        case "gap":
            self = .gap(
                id: id,
                prompt: prompt,
                answer: try container.decodeIfPresent(String.self, forKey: .answer) ?? "",
                accepts: try container.decodeIfPresent([String].self, forKey: .accepts) ?? [],
                why: why
            )
        case "feynman":
            self = .feynman(
                id: id,
                prompt: prompt,
                expected: try container.decodeIfPresent(String.self, forKey: .expected) ?? ""
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Question inconnue : \(kind)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kindName, forKey: .kind)
        try container.encode(id, forKey: .id)
        try container.encode(prompt, forKey: .prompt)
        switch self {
        case .choice(_, _, let choices, let answerIndex, let why):
            try container.encode(choices, forKey: .choices)
            try container.encode(answerIndex, forKey: .answerIndex)
            try container.encode(why, forKey: .why)
        case .trueFalse(_, _, let answer, let why):
            try container.encode(answer, forKey: .answer)
            try container.encode(why, forKey: .why)
        case .gap(_, _, let answer, let accepts, let why):
            try container.encode(answer, forKey: .answer)
            if !accepts.isEmpty { try container.encode(accepts, forKey: .accepts) }
            try container.encode(why, forKey: .why)
        case .feynman(_, _, let expected):
            try container.encode(expected, forKey: .expected)
        }
    }
}

/// Ce que l'étudiant a posé sur la copie. Tout à `nil` quand il a laissé blanc.
struct MockAnswer: Codable, Equatable {
    var id: String
    /// Index coché, pour un QCM.
    var choiceIndex: Int?
    /// Vrai ou faux coché.
    var truth: Bool?
    /// Ce qui est écrit ou dicté.
    var text: String?

    init(id: String, choiceIndex: Int? = nil, truth: Bool? = nil, text: String? = nil) {
        self.id = id
        self.choiceIndex = choiceIndex
        self.truth = truth
        self.text = text
    }

    var isAnswered: Bool {
        if choiceIndex != nil || truth != nil { return true }
        return !(text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// La correction d'une question, une fois la copie remise.
struct MockGrade: Codable, Equatable {
    var id: String
    /// 0 à 100. Les questions fermées ne rendent que 0 ou 100.
    var score: Int
    /// Ce que la correction a à dire. Vide sur une question fermée réussie.
    var comment: String?

    init(id: String, score: Int, comment: String? = nil) {
        self.id = id
        self.score = MockPaper.clamp(score)
        self.comment = comment
    }

    private enum CodingKeys: String, CodingKey { case id, score, comment }

    /// Le modèle rend parfois `70.0` : on arrondit plutôt que de refuser la ligne.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let raw = try container.decodeIfPresent(Double.self, forKey: .score) ?? 0
        score = MockPaper.clamp(Int(raw.rounded()))
        comment = try container.decodeIfPresent(String.self, forKey: .comment)?.nilIfBlank
    }
}

/// Le débriefing du modèle : une phrase, ce qui tient, ce qui ne tient pas, quoi faire.
struct MockDebrief: Codable, Equatable {
    var headline: String
    var strengths: [String]
    var gaps: [String]
    var advice: String

    init(headline: String, strengths: [String], gaps: [String], advice: String) {
        self.headline = headline
        self.strengths = strengths
        self.gaps = gaps
        self.advice = advice
    }

    private enum CodingKeys: String, CodingKey { case headline, strengths, gaps, advice }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        headline = try container.decodeIfPresent(String.self, forKey: .headline) ?? ""
        strengths = try container.decodeIfPresent([String].self, forKey: .strengths) ?? []
        gaps = try container.decodeIfPresent([String].self, forKey: .gaps) ?? []
        advice = try container.decodeIfPresent(String.self, forKey: .advice) ?? ""
    }

    var isEmpty: Bool {
        headline.isEmpty && strengths.isEmpty && gaps.isEmpty && advice.isEmpty
    }
}

/// Les règles de la copie : composition, temps imparti, correction des fermées, note.
///
/// Chaque fonction est la traduction de celle du même nom dans `mock-paper.ts`. Si l'une des
/// deux change, l'autre doit changer : un score qui ne serait pas le même selon l'appareil qui
/// corrige ne serait plus une mesure.
enum MockPaper {
    /// Vingt questions, comme une vraie épreuve courte.
    static let size = 20
    /// Une question à 60 % est acquise, au sens où on le raconte.
    static let passMark = 60

    struct Quota: Equatable {
        var choice: Int
        var trueFalse: Int
        var gap: Int
        var feynman: Int

        var total: Int { choice + trueFalse + gap + feynman }
    }

    /// La composition demandée au modèle. Sans micro, les questions orales deviennent des
    /// questions fermées : la copie garde ses vingt questions, et le score reste comparable.
    static func quota(withAudio: Bool, size: Int = size) -> Quota {
        let total = max(4, size)
        let feynman = withAudio ? max(1, Int((Double(total) * 0.15).rounded())) : 0
        let rest = total - feynman
        let choice = Int((Double(rest) * 0.5).rounded())
        let gap = Int((Double(rest) * 0.25).rounded())
        return Quota(choice: choice, trueFalse: rest - choice - gap, gap: gap, feynman: feynman)
    }

    /// Le temps imparti : une minute par question fermée, deux par question orale.
    static func minutes(for questions: [MockQuestion]) -> Int {
        let closed = questions.filter(\.isClosed).count
        let spoken = questions.count - closed
        return max(5, closed + spoken * 2)
    }

    /// Deux réponses écrites sont la même quand elles disent le même mot : on ignore la
    /// casse, les accents, la ponctuation et les articles. On ne va pas plus loin.
    static func normalize(_ value: String) -> String {
        var text = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
        text = text.replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(
            of: "\\b(le|la|les|l|un|une|des|du|de|d|the|a|an|el|los|las|der|die|das|ein|eine)\\b",
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespaces)
    }

    static func sameAnswer(_ said: String, _ expected: String) -> Bool {
        let left = normalize(said)
        return !left.isEmpty && left == normalize(expected)
    }

    /// La note d'une question fermée : juste ou faux, sans nuance et sans modèle. `nil` pour
    /// une question orale, qui ne se corrige pas ici.
    static func gradeClosed(_ question: MockQuestion, answer: MockAnswer?) -> MockGrade? {
        switch question {
        case .choice(let id, _, _, let answerIndex, let why):
            let picked = answer?.choiceIndex
            return MockGrade(id: id, score: picked != nil && picked == answerIndex ? 100 : 0, comment: why.nilIfBlank)
        case .trueFalse(let id, _, let expected, let why):
            let picked = answer?.truth
            return MockGrade(id: id, score: picked != nil && picked == expected ? 100 : 0, comment: why.nilIfBlank)
        case .gap(let id, _, let expected, let accepts, let why):
            let said = answer?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let accepted = [expected] + accepts
            let right = accepted.contains { sameAnswer(said, $0) }
            return MockGrade(id: id, score: right ? 100 : 0, comment: why.nilIfBlank)
        case .feynman:
            return nil
        }
    }

    /// La note de la copie : la moyenne des questions, sur cent. Une question Feynman pèse
    /// comme une question fermée.
    static func score(of grades: [MockGrade]) -> Int {
        guard !grades.isEmpty else { return 0 }
        let total = grades.reduce(0) { $0 + clamp($1.score) }
        return Int((Double(total) / Double(grades.count)).rounded())
    }

    static func correctCount(_ grades: [MockGrade]) -> Int {
        grades.filter { clamp($0.score) >= passMark }.count
    }

    static func clamp(_ value: Int) -> Int {
        max(0, min(100, value))
    }

    /// Ce que l'étudiant a répondu, en clair, pour le débriefing.
    static func said(_ question: MockQuestion, answer: MockAnswer?, blank: String, yes: String, no: String) -> String {
        switch question {
        case .choice(_, _, let choices, _, _):
            guard let index = answer?.choiceIndex, choices.indices.contains(index) else { return blank }
            return choices[index]
        case .trueFalse:
            guard let truth = answer?.truth else { return blank }
            return truth ? yes : no
        case .gap, .feynman:
            let text = answer?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? blank : text
        }
    }

    /// La bonne réponse d'une question fermée, en clair.
    static func expected(_ question: MockQuestion, yes: String, no: String) -> String? {
        switch question {
        case .choice(_, _, let choices, let answerIndex, _):
            return choices.indices.contains(answerIndex) ? choices[answerIndex] : nil
        case .trueFalse(_, _, let answer, _):
            return answer ? yes : no
        case .gap(_, _, let answer, _, _):
            return answer
        case .feynman:
            return nil
        }
    }
}
