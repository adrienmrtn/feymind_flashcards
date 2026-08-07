import Foundation
import SwiftData

enum CourseSource: String, Codable, CaseIterable {
    case text
    case pdf
    case library
    case sample

    var label: String {
        switch self {
        case .text: "Texte"
        case .pdf: "PDF"
        case .library: "Bibliothèque"
        case .sample: "Exemple"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "text.alignleft"
        case .pdf: "doc.fill"
        case .library: "globe.europe.africa.fill"
        case .sample: "sparkles"
        }
    }
}

@Model
final class Course {
    var id: UUID = UUID()
    var title: String = ""
    var subject: String?
    var summary: String = ""
    var emoji: String = "📘"
    var accentHex: String = "5B54E8"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sourceRaw: String = CourseSource.text.rawValue
    var sourceFileName: String?
    /// Texte source brut, conservé pour régénérer des flashcards ou expliquer un passage.
    var rawText: String = ""
    var readingMinutes: Int = 5
    var isFromLibrary: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \CourseBlockEntity.course)
    var blockEntities: [CourseBlockEntity]? = []

    @Relationship(deleteRule: .cascade, inverse: \Flashcard.course)
    var flashcards: [Flashcard]? = []

    @Relationship(deleteRule: .cascade, inverse: \TextHighlight.course)
    var highlights: [TextHighlight]? = []

    init(
        id: UUID = UUID(),
        title: String,
        subject: String? = nil,
        summary: String = "",
        emoji: String = "📘",
        accentHex: String = "5B54E8",
        source: CourseSource = .text,
        sourceFileName: String? = nil,
        rawText: String = "",
        readingMinutes: Int = 5,
        isFromLibrary: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subject = subject
        self.summary = summary
        self.emoji = emoji
        self.accentHex = accentHex
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sourceRaw = source.rawValue
        self.sourceFileName = sourceFileName
        self.rawText = rawText
        self.readingMinutes = readingMinutes
        self.isFromLibrary = isFromLibrary
        self.blockEntities = []
        self.flashcards = []
        self.highlights = []
    }

    var source: CourseSource {
        get { CourseSource(rawValue: sourceRaw) ?? .text }
        set { sourceRaw = newValue.rawValue }
    }

    /// Blocs triés dans l'ordre de lecture.
    var orderedBlocks: [CourseBlockEntity] {
        (blockEntities ?? []).sorted { $0.position < $1.position }
    }

    var cards: [Flashcard] {
        flashcards ?? []
    }

    var dueCards: [Flashcard] {
        cards.filter { $0.isDue() }
    }

    func highlights(for blockId: UUID) -> [TextHighlight] {
        (highlights ?? []).filter { $0.blockId == blockId }
    }

    /// Contexte condensé du cours, envoyé à l'IA pour les flashcards.
    func contextSnippet(limit: Int = 6000) -> String {
        var text = "Titre : \(title)\n"
        if let subject { text += "Matière : \(subject)\n" }
        text += summary + "\n\n"
        for block in orderedBlocks {
            guard let payload = block.payload else { continue }
            let line = payload.plainText
            if line.isEmpty { continue }
            if text.count + line.count > limit { break }
            text += line + "\n"
        }
        if orderedBlocks.isEmpty, !rawText.isEmpty {
            text += String(rawText.prefix(max(0, limit - text.count)))
        }
        return text
    }
}

@Model
final class CourseBlockEntity {
    var id: UUID = UUID()
    var position: Int = 0
    var kindRaw: String = CourseBlockKind.paragraph.rawValue
    var payloadData: Data = Data()
    var course: Course?

    init(position: Int, payload: CourseBlockPayload) {
        self.id = UUID()
        self.position = position
        self.kindRaw = payload.kind.rawValue
        self.payloadData = (try? JSONEncoder().encode(payload)) ?? Data()
    }

    var kind: CourseBlockKind {
        CourseBlockKind(rawValue: kindRaw) ?? .paragraph
    }

    var payload: CourseBlockPayload? {
        try? JSONDecoder().decode(CourseBlockPayload.self, from: payloadData)
    }
}
