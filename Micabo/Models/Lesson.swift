import Foundation

/// **Le plan d'une leçon** : ce qui fait d'un cours un parcours.
///
/// Écrit par le modèle au moment où la leçon naît (`lesson-plan`), ou à la conversion d'un
/// ancien cours (`lesson-convert`). Les thèmes, eux, sont les `Chapter` du cours : un thème =
/// un cercle Notes. Encodé en JSON dans `Course.pathData` et `courses.path`.
///
/// Voir `docs/refonte-parcours.md` § 5 et § 8.
struct LessonPath: Codable, Equatable {
    /// L'écran « Ce que tu vas apprendre ».
    struct Intro: Codable, Equatable {
        /// Trois lignes.
        var lines: [String]
        /// « Temps estimé : 25 min ».
        var minutes: Int
    }

    /// Un palier : un groupe de thèmes, et son nom (« Les causes »). Son quiz suit ses thèmes.
    struct Group: Codable, Equatable {
        var name: String
        /// Les rangs des thèmes du groupe, dans l'ordre.
        var themes: [Int]
    }

    enum Status: String, Codable {
        /// Le plan est là, des thèmes s'écrivent encore.
        case generating
        case ready
        /// Le plan lui-même a échoué : la leçon ne peut pas se construire.
        case failed
    }

    var version: Int = 1
    /// L'icône de la leçon, dans la base (`MicaboIcon`).
    var icon: String
    var intro: Intro
    /// « À retenir » : cinq phrases clés.
    var takeaways: [String]
    var groups: [Group]
    /// Les supports dépassaient 60 000 caractères et ont été coupés.
    var shortened: Bool = false
    /// Leçon très courte : un seul quiz pour tous les thèmes.
    var singleQuiz: Bool = false
    var status: Status = .generating
    /// Le pictogramme de chaque thème sur le chemin (`PathSymbol`), dans l'ordre des thèmes,
    /// tous différents. Absent sur une leçon d'avant : l'app en choisit.
    var symbols: [String]?
    /// Les notions que chaque thème doit couvrir, données par le plan : elles bornent
    /// l'écriture du thème, et « Réessayer » les renvoie telles quelles.
    var points: [[String]]?

    static func decode(from data: Data?) -> LessonPath? {
        guard let data, !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(LessonPath.self, from: data)
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }
}

/// **Les notes d'un thème**, au format de la refonte (§ 6) : une idée en une phrase, des blocs
/// courts (quatre à dix selon le niveau de l'élève), des blocs spéciaux et des encadrés quand
/// le contenu le demande, trois phrases à retenir.
///
/// Encodé en JSON dans `Chapter.notesData` et `chapters.notes`. Un ancien chapitre n'en a pas :
/// il garde sa fiche (`Chapter.sheetData`), affichée avec la même typographie.
struct ThemeNotes: Codable, Equatable {
    var oneLiner: String
    var blocks: [NoteBlock]
    var takeaways: [String]

    enum CodingKeys: String, CodingKey {
        case oneLiner, blocks, takeaways
    }

    static func decode(from data: Data?) -> ThemeNotes? {
        guard let data, !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(ThemeNotes.self, from: data)
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Le texte à plat, pour le contexte de Mika et la relecture.
    var plainText: String {
        var lines = [oneLiner]
        for block in blocks {
            switch block {
            case .subtitle(let text), .paragraph(let text), .example(let text):
                lines.append(text)
            case .list(let items):
                lines.append(contentsOf: items.map { "- " + $0 })
            case .definition(let term, let text):
                lines.append("\(term) : \(text)")
            case .dates(let items):
                lines.append(contentsOf: items.map { "\($0.date) : \($0.text)" })
            case .formula(let latex, let caption):
                lines.append([latex, caption].compactMap { $0 }.joined(separator: " — "))
            case .steps(let items):
                lines.append(contentsOf: items.enumerated().map { "\($0.offset + 1). \($0.element)" })
            case .table(let columns, let rows):
                lines.append(columns.joined(separator: " | "))
                lines.append(contentsOf: rows.map { $0.joined(separator: " | ") })
            case .quote(let text, let author):
                lines.append(["« \(text) »", author].compactMap { $0 }.joined(separator: " — "))
            case .callout(_, let title, let text):
                lines.append([title, text].compactMap { $0 }.joined(separator: " : "))
            }
        }
        lines.append(contentsOf: takeaways)
        return lines.joined(separator: "\n").replacingOccurrences(of: "**", with: "")
    }
}

extension ThemeNotes {
    /// Les blocs se lisent un par un : un bloc illisible (une forme inconnue sans texte de
    /// repli, un champ manquant) disparaît, au lieu de laisser un trou blanc ou de faire
    /// tomber toutes les notes du thème. Écrit dans une extension pour garder l'initialiseur
    /// membre à membre.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        oneLiner = try container.decode(String.self, forKey: .oneLiner)
        blocks = try container.decode([LossyNoteBlock].self, forKey: .blocks)
            .compactMap(\.block)
            .flatMap(\.repaired)
            .filter { !$0.isEmpty }
        takeaways = try container.decode([String].self, forKey: .takeaways)
    }
}

/// Un bloc qui se décode sans jamais échouer : `nil` quand il est illisible.
private struct LossyNoteBlock: Decodable {
    let block: NoteBlock?

    init(from decoder: Decoder) throws {
        block = try? NoteBlock(from: decoder)
    }
}

/// Un bloc des notes. Le balisage en ligne ne garde que `**mot-clé**` (gras violet) et
/// `$latex$`.
///
/// Les formes `steps`, `table` et `quote` arrivent avec un champ `text` de repli, pour les
/// versions de l'app qui ne les connaissent pas : on l'ignore ici, sauf si le bloc est
/// incomplet. L'encadré (`callout`) a son texte dans `text` : une version qui ne le connaît
/// pas le lit en paragraphe.
enum NoteBlock: Codable, Equatable {
    struct DateItem: Codable, Equatable {
        var date: String
        var text: String
    }

    case subtitle(String)
    case paragraph(String)
    case list([String])
    case definition(term: String, text: String)
    case dates([DateItem])
    case formula(latex: String, caption: String?)
    case example(String)
    /// Des étapes numérotées, dans l'ordre.
    case steps([String])
    /// Un petit tableau : deux à quatre colonnes, des cellules courtes.
    case table(columns: [String], rows: [[String]])
    /// Une citation, et qui l'a dite.
    case quote(text: String, author: String?)
    /// Un encadré qui enseigne : pourquoi ça compte, le piège, l'astuce, la règle à retenir.
    /// L'app écrit toujours le nom de son genre ; le titre, facultatif, vient dessous.
    case callout(kind: CalloutKind, title: String?, text: String)

    private enum CodingKeys: String, CodingKey {
        case type, text, items, term, latex, caption, columns, rows, author, kind, title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "subtitle":
            self = .subtitle(try container.decode(String.self, forKey: .text))
        case "paragraph":
            self = .paragraph(try container.decode(String.self, forKey: .text))
        case "list":
            self = .list(try container.decode([String].self, forKey: .items))
        case "definition":
            self = .definition(
                term: try container.decode(String.self, forKey: .term),
                text: try container.decode(String.self, forKey: .text)
            )
        case "dates":
            self = .dates(try container.decode([DateItem].self, forKey: .items))
        case "formula":
            let latex = try container.decode(String.self, forKey: .latex)
            let caption = try container.decodeIfPresent(String.self, forKey: .caption)
            // Le serveur ramène la formule à ce que le moteur compose ; une leçon écrite avant
            // garde son `\xrightarrow{Lumière}`, affiché « xrightarrowLumière » : réparée ici.
            let normalized = SheetText.normalizedFormula(latex, caption: caption)
            self = .formula(latex: normalized?.latex ?? latex, caption: normalized?.caption ?? caption)
        case "example":
            self = .example(try container.decode(String.self, forKey: .text))
        case "steps":
            let items = (try? container.decode([String].self, forKey: .items)) ?? []
            self = try items.isEmpty ? Self.fallback(in: container) : .steps(items)
        case "table":
            let columns = (try? container.decode([String].self, forKey: .columns)) ?? []
            let rows = (try? container.decode([[String]].self, forKey: .rows)) ?? []
            self = try columns.isEmpty || rows.isEmpty
                ? Self.fallback(in: container)
                : .table(columns: columns, rows: rows)
        case "quote":
            let text = try container.decode(String.self, forKey: .text)
            let author = (try container.decodeIfPresent(String.self, forKey: .author))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            self = .quote(text: text, author: (author?.isEmpty ?? true) ? nil : author)
        case "callout":
            let text = try container.decode(String.self, forKey: .text)
            // Un genre inconnu (d'une version plus récente du serveur) se lit comme une astuce.
            let rawKind = (try? container.decodeIfPresent(String.self, forKey: .kind)) ?? nil
            let kind = rawKind.flatMap(CalloutKind.init(rawValue:)) ?? .tip
            let rawTitle = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? nil
            let title = rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            self = .callout(kind: kind, title: (title?.isEmpty ?? true) ? nil : title, text: text)
        default:
            // Un bloc d'une version plus récente du serveur se lit comme un paragraphe plutôt
            // que de faire tomber toutes les notes du thème.
            self = try Self.fallback(in: container)
        }
    }

    /// Le texte de repli d'un bloc, en paragraphe. Sans texte, le bloc est illisible :
    /// `ThemeNotes` le retire plutôt que d'afficher un paragraphe vide.
    private static func fallback(in container: KeyedDecodingContainer<CodingKeys>) throws -> NoteBlock {
        let text = try? container.decodeIfPresent(String.self, forKey: .text)
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .text,
                in: container,
                debugDescription: "Bloc sans contenu lisible."
            )
        }
        return .paragraph(text)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .subtitle(let text):
            try container.encode("subtitle", forKey: .type)
            try container.encode(text, forKey: .text)
        case .paragraph(let text):
            try container.encode("paragraph", forKey: .type)
            try container.encode(text, forKey: .text)
        case .list(let items):
            try container.encode("list", forKey: .type)
            try container.encode(items, forKey: .items)
        case .definition(let term, let text):
            try container.encode("definition", forKey: .type)
            try container.encode(term, forKey: .term)
            try container.encode(text, forKey: .text)
        case .dates(let items):
            try container.encode("dates", forKey: .type)
            try container.encode(items, forKey: .items)
        case .formula(let latex, let caption):
            try container.encode("formula", forKey: .type)
            try container.encode(latex, forKey: .latex)
            try container.encodeIfPresent(caption, forKey: .caption)
        case .example(let text):
            try container.encode("example", forKey: .type)
            try container.encode(text, forKey: .text)
        case .steps(let items):
            try container.encode("steps", forKey: .type)
            try container.encode(items, forKey: .items)
        case .table(let columns, let rows):
            try container.encode("table", forKey: .type)
            try container.encode(columns, forKey: .columns)
            try container.encode(rows, forKey: .rows)
        case .quote(let text, let author):
            try container.encode("quote", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(author, forKey: .author)
        case .callout(let kind, let title, let text):
            try container.encode("callout", forKey: .type)
            try container.encode(kind.rawValue, forKey: .kind)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encode(text, forKey: .text)
        }
    }

    /// Vrai pour les blocs qui se dessinent dans un encadré : deux encadrés ne se suivent pas.
    var isBoxed: Bool {
        switch self {
        case .definition, .formula, .example, .steps, .table, .quote, .callout: true
        default: false
        }
    }

    /// Vrai pour un bloc qui n'a rien à montrer : il laisserait un trou blanc.
    var isEmpty: Bool {
        switch self {
        case .subtitle(let text), .paragraph(let text), .callout(_, _, let text):
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            false
        }
    }

    /// Le nombre de mots que le bloc donne à lire : ce qui remplit, ou non, un écran.
    var wordCount: Int {
        let pieces: [String]
        switch self {
        case .subtitle(let text), .paragraph(let text), .example(let text):
            pieces = [text]
        case .list(let items), .steps(let items):
            pieces = items
        case .definition(let term, let text):
            pieces = [term, text]
        case .dates(let items):
            pieces = items.flatMap { [$0.date, $0.text] }
        case .formula(_, let caption):
            pieces = [caption ?? ""]
        case .table(let columns, let rows):
            pieces = columns + rows.flatMap { $0 }
        case .quote(let text, let author):
            pieces = [text, author ?? ""]
        case .callout(_, let title, let text):
            pieces = [title ?? "", text]
        }
        return pieces.reduce(0) { $0 + $1.split(whereSeparator: \.isWhitespace).count }
    }

    /// **Des étapes écrites d'une traite dans un paragraphe.** « 1. La lumière est absorbée…
    /// 2. L'eau est décomposée… 3. … » arrivait en un pavé numéroté. Le serveur en fait des
    /// étapes depuis ; les leçons écrites avant sont réparées ici, à la lecture : ce qui précède
    /// le premier numéro reste un paragraphe d'introduction, le reste devient des étapes.
    var repaired: [NoteBlock] {
        guard case .paragraph(let text) = self, let split = Self.inlineSteps(in: text) else { return [self] }
        return (split.lead.isEmpty ? [] : [.paragraph(split.lead)]) + [.steps(split.items)]
    }

    /// Trois numéros au moins, qui se suivent depuis 1, en début de texte ou après un blanc :
    /// une date (« en 1945. ») ou un « 2 » isolé ne font pas une méthode.
    ///
    /// Jumeau de `inlineSteps` dans `supabase/functions/generate-lesson/schema.ts`, sans ses
    /// plafonds de longueur : le serveur coupe ce qui dépasse, l'app ne coupe rien.
    static func inlineSteps(in text: String) -> (lead: String, items: [String])? {
        guard let marker = try? NSRegularExpression(pattern: "(?:^|(?<=[\\s:;]))(\\d{1,2})[.)]\\s+") else {
            return nil
        }
        let source = text as NSString
        var sequence: [NSRange] = []
        for match in marker.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            if Int(source.substring(with: match.range(at: 1))) == sequence.count + 1 {
                sequence.append(match.range)
            }
        }
        guard sequence.count >= 3 else { return nil }
        let items: [String] = sequence.enumerated().map { index, range in
            let start = range.location + range.length
            let end = index + 1 < sequence.count ? sequence[index + 1].location : source.length
            // « 1. poser l'opération ; 2. calculer » : le point-virgule séparait, il ne finit pas l'étape.
            var item = source.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if item.last == ";" || item.last == "," {
                item = String(item.dropLast()).trimmingCharacters(in: .whitespaces)
            }
            return item
        }
        guard items.allSatisfy({ $0.count >= 2 }) else { return nil }
        let lead = source.substring(to: sequence[0].location).trimmingCharacters(in: .whitespacesAndNewlines)
        return (lead, items)
    }
}

/// Le genre d'un encadré des notes. Voir `supabase/functions/generate-lesson/schema.ts`.
enum CalloutKind: String, Codable, CaseIterable, Sendable {
    /// Pourquoi ça compte : l'intuition derrière la règle.
    case why
    /// L'erreur classique, et comment l'éviter.
    case mistake
    /// Une astuce de méthode, un moyen mnémotechnique.
    case tip
    /// Une règle à savoir par cœur.
    case remember

    /// Le titre de l'encadré quand le serveur n'en donne pas (`lesson.notes.callout.*`).
    var titleKey: String {
        switch self {
        case .why: "lesson.notes.callout.why"
        case .mistake: "lesson.notes.callout.mistake"
        case .tip: "lesson.notes.callout.tip"
        case .remember: "lesson.notes.callout.remember"
        }
    }

    /// Le nom du genre pour le modèle, quand les notes lui sont relues : en français, comme
    /// toutes les consignes.
    var promptLabel: String {
        switch self {
        case .why: "Pourquoi"
        case .mistake: "Piège"
        case .tip: "Astuce"
        case .remember: "À retenir"
        }
    }
}

/// La forme d'une question. Voir `supabase/functions/generate-lesson/schema.ts`.
enum QuizKind: String, Codable, CaseIterable, Sendable {
    /// Un QCM : `choices`, une seule bonne (`answer`).
    case choice
    /// Une affirmation à juger : `choices` vaut « Vrai », « Faux » dans la langue des notes.
    case truefalse
    /// Une phrase à trou (`ClozeGap.marker`) et ses propositions.
    case gap
    /// Des éléments à remettre dans l'ordre : `choices` est dans le BON ordre, l'app mélange.
    case order
    /// Des paires à associer : `choices` à gauche, `matches` à droite, dans le même ordre.
    case match
}

/// **Une question** : la question de fin d'un thème, une des questions de réserve qui font
/// les quiz, ou une question d'entraînement écrite plus tard. Cinq formes (`QuizKind`), une
/// difficulté de 1 (reconnaître) à 3 (appliquer), une phrase qui explique.
struct QuizQuestion: Codable, Equatable, Identifiable {
    /// Stable : `<id du thème>:<rang>`, ou `<id du thème>:p<n>` pour l'entraînement. C'est lui
    /// qu'on retient pour « ratée ».
    var id: String
    var kind: QuizKind
    var prompt: String
    var choices: [String]
    var answer: Int
    var why: String
    var matches: [String]
    var difficulty: Int

    init(
        id: String,
        kind: QuizKind = .choice,
        prompt: String,
        choices: [String],
        answer: Int,
        why: String,
        matches: [String] = [],
        difficulty: Int = 2
    ) {
        self.id = id
        self.kind = kind
        self.prompt = prompt
        self.choices = choices
        self.answer = answer
        self.why = why
        self.matches = matches
        self.difficulty = min(3, max(1, difficulty))
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, prompt, choices, answer, why, matches, difficulty
    }

    /// Une question d'avant les formes est un QCM ; une forme inconnue aussi.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = (try container.decodeIfPresent(String.self, forKey: .kind)).flatMap(QuizKind.init(rawValue:)) ?? .choice
        prompt = try container.decode(String.self, forKey: .prompt)
        choices = try container.decodeIfPresent([String].self, forKey: .choices) ?? []
        answer = try container.decodeIfPresent(Int.self, forKey: .answer) ?? 0
        why = try container.decodeIfPresent(String.self, forKey: .why) ?? ""
        matches = try container.decodeIfPresent([String].self, forKey: .matches) ?? []
        difficulty = min(3, max(1, try container.decodeIfPresent(Int.self, forKey: .difficulty) ?? 2))
    }

    var isValid: Bool {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch kind {
        case .choice, .truefalse, .gap:
            return choices.count >= 2 && choices.indices.contains(answer)
        case .order:
            return choices.count >= 3
        case .match:
            return choices.count >= 2 && matches.count == choices.count
        }
    }

    /// La bonne réponse, en clair : pour le corrigé et pour une carte faite d'une question ratée.
    var answerText: String {
        switch kind {
        case .choice, .truefalse, .gap:
            return choices.indices.contains(answer) ? choices[answer] : ""
        case .order:
            return choices.joined(separator: " → ")
        case .match:
            return zip(choices, matches).map { "\($0) : \($1)" }.joined(separator: " · ")
        }
    }
}

/// Les questions d'un thème : la première est la question de fin, les autres font la réserve
/// des quiz. Encodé en JSON dans `Chapter.quizData` et `chapters.quiz`.
struct ThemeQuiz: Codable, Equatable {
    var questions: [QuizQuestion]

    var final: QuizQuestion? { questions.first }
    var reserve: [QuizQuestion] { Array(questions.dropFirst()) }

    static func decode(from data: Data?) -> ThemeQuiz? {
        guard let data, !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(ThemeQuiz.self, from: data)
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }
}

/// **Où en est l'élève dans sa leçon.** Encodé en JSON dans `Course.progressData` et
/// `courses.progress`.
struct LessonProgress: Codable, Equatable {
    /// Les cercles cochés, par identifiant (`PathCircle.ID`).
    var done: Set<String> = []
    /// Où on en est **dans** le cercle en cours, entre 0 et 1 : l'anneau autour de lui.
    var inCircle: Double = 0
    /// Les scores des quiz : identifiant du cercle → [bonnes réponses, questions].
    var quizScores: [String: [Int]] = [:]
    /// Les questions ratées (`QuizQuestion.id`), les plus récentes à la fin.
    var missed: [String] = []
    /// Le temps passé, en secondes, par activité : `notes`, `quiz`, `flashcards`.
    var seconds: [String: Double] = [:]
    /// Le jour où la leçon est devenue « apprise ».
    var finishedAt: Date?

    static func decode(from data: Data?) -> LessonProgress {
        guard let data, !data.isEmpty,
              let progress = try? JSONDecoder.lessonDates.decode(LessonProgress.self, from: data)
        else { return LessonProgress() }
        return progress
    }

    func encoded() -> Data? {
        try? JSONEncoder.lessonDates.encode(self)
    }

    var totalSeconds: Double { seconds.values.reduce(0, +) }

    /// Le score moyen des quiz, en pour cent ; `nil` sans quiz fait.
    var averageQuizPercent: Int? {
        let scores = quizScores.values.filter { $0.count == 2 && $0[1] > 0 }
        guard !scores.isEmpty else { return nil }
        let right = scores.reduce(0) { $0 + $1[0] }
        let total = scores.reduce(0) { $0 + $1[1] }
        return Int((Double(right) / Double(total) * 100).rounded())
    }

    mutating func addTime(_ interval: TimeInterval, to activity: LessonActivity) {
        guard interval > 0, interval < 6 * 3600 else { return }
        seconds[activity.rawValue, default: 0] += interval
    }

    mutating func noteMissed(_ id: String) {
        missed.removeAll { $0 == id }
        missed.append(id)
        if missed.count > 200 { missed.removeFirst(missed.count - 200) }
    }

    mutating func noteRight(_ id: String) {
        missed.removeAll { $0 == id }
    }
}

/// Ce qui compte dans « X h de révision ».
enum LessonActivity: String, Codable, CaseIterable {
    case notes
    case quiz
    case flashcards
}

extension JSONEncoder {
    /// Les dates en ISO 8601 : c'est ce que le web et Postgres lisent sans traduction.
    static var lessonDates: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var lessonDates: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// L'état de génération d'un thème.
enum ThemeStatus: String, Codable {
    /// Le thème est annoncé par le plan, ses notes s'écrivent.
    case pending
    case ready
    /// L'écriture a échoué : le cercle propose « Réessayer ».
    case failed
}
