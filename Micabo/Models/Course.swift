import Foundation
import SwiftData

enum CourseSource: String, Codable, CaseIterable {
    case text
    case pdf
    case photo
    case docx
    case library
    case sample

    var label: String {
        switch self {
        case .text: "Texte"
        case .pdf: "PDF"
        case .photo: "Photos"
        case .docx: "Word"
        case .library: "Bibliothèque"
        case .sample: "Exemple"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "text.alignleft"
        case .pdf: "doc.fill"
        case .photo: "photo.on.rectangle.angled"
        case .docx: "doc.richtext"
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
    var accentHex: String = "2F4858"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sourceRaw: String = CourseSource.text.rawValue
    var sourceFileName: String?
    /// Texte source brut, conservé pour régénérer des flashcards.
    var rawText: String = ""
    /// Contenu analysé par l'IA, servant de contexte aux nouvelles cartes.
    var contextText: String = ""
    /// Première page ou photo, utilisée comme couverture.
    @Attribute(.externalStorage) var coverImageData: Data?
    var isFromLibrary: Bool = false
    /// Empreinte du contenu importé, pour reconnaître un chapitre déjà présent.
    var fingerprint: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Flashcard.course)
    var flashcards: [Flashcard]? = []

    init(
        id: UUID = UUID(),
        title: String,
        subject: String? = nil,
        summary: String = "",
        emoji: String = "📘",
        accentHex: String = "2F4858",
        source: CourseSource = .text,
        sourceFileName: String? = nil,
        rawText: String = "",
        contextText: String = "",
        coverImageData: Data? = nil,
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
        self.contextText = contextText
        self.coverImageData = coverImageData
        self.isFromLibrary = isFromLibrary
        self.flashcards = []
    }

    var source: CourseSource {
        get { CourseSource(rawValue: sourceRaw) ?? .text }
        set { sourceRaw = newValue.rawValue }
    }

    var cards: [Flashcard] {
        flashcards ?? []
    }

    var orderedCards: [Flashcard] {
        cards.sorted { $0.position < $1.position }
    }

    var dueCards: [Flashcard] {
        cards.filter { $0.isDue() }
    }

    var newCards: [Flashcard] {
        cards.filter { $0.state == .new }
    }

    /// Contexte condensé du cours, envoyé à l'IA pour rédiger de nouvelles cartes.
    func contextSnippet(limit: Int = 6000) -> String {
        var header = "Titre : \(title)\n"
        if let subject, !subject.isEmpty { header += "Matière : \(subject)\n" }
        if !summary.isEmpty { header += summary + "\n\n" }

        let body = contextText.isEmpty ? rawText : contextText
        let remaining = max(0, limit - header.count)
        return header + String(body.prefix(remaining))
    }
}
