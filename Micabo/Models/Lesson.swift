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

    static func decode(from data: Data?) -> LessonPath? {
        guard let data, !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(LessonPath.self, from: data)
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }
}

/// **Les notes d'un thème**, au format de la refonte (§ 6) : une idée en une phrase, deux à
/// cinq blocs courts, des blocs spéciaux quand le contenu le demande, trois phrases à retenir.
///
/// Encodé en JSON dans `Chapter.notesData` et `chapters.notes`. Un ancien chapitre n'en a pas :
/// il garde sa fiche (`Chapter.sheetData`), affichée avec la même typographie.
struct ThemeNotes: Codable, Equatable {
    var oneLiner: String
    var blocks: [NoteBlock]
    var takeaways: [String]

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
            }
        }
        lines.append(contentsOf: takeaways)
        return lines.joined(separator: "\n").replacingOccurrences(of: "**", with: "")
    }
}

/// Un bloc des notes. Le balisage en ligne ne garde que `**mot-clé**` (gras violet) et
/// `$latex$`.
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

    private enum CodingKeys: String, CodingKey {
        case type, text, items, term, latex, caption
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
            self = .formula(
                latex: try container.decode(String.self, forKey: .latex),
                caption: try container.decodeIfPresent(String.self, forKey: .caption)
            )
        case "example":
            self = .example(try container.decode(String.self, forKey: .text))
        default:
            // Un bloc d'une version plus récente du serveur se lit comme un paragraphe plutôt
            // que de faire tomber toutes les notes du thème.
            let text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
            self = .paragraph(text)
        }
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
        }
    }

    /// Vrai pour les blocs qui se dessinent dans un encadré : deux encadrés ne se suivent pas.
    var isBoxed: Bool {
        switch self {
        case .definition, .formula, .example: true
        default: false
        }
    }
}

/// **Un QCM** : la question de fin d'un thème, ou une des questions de réserve qui font les
/// quiz. Quatre choix, une bonne réponse, une phrase qui explique.
struct QuizQuestion: Codable, Equatable, Identifiable {
    /// Stable : `<id du thème>:<rang>`. C'est lui qu'on retient pour « ratée ».
    var id: String
    var prompt: String
    var choices: [String]
    var answer: Int
    var why: String

    var isValid: Bool {
        choices.count >= 2 && choices.indices.contains(answer)
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
