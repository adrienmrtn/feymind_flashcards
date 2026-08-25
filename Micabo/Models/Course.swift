import Foundation
import SwiftData

enum CourseSource: String, Codable, CaseIterable {
    case text
    case pdf
    case photo
    case docx
    case youtube
    case library
    case sample

    var label: String {
        switch self {
        case .text: "Texte"
        case .pdf: "PDF"
        case .photo: "Photos"
        case .docx: "Word"
        case .youtube: "YouTube"
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
        case .youtube: "play.rectangle.fill"
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
    /// Texte source brut, conservé pour régénérer la fiche ou des cartes.
    var rawText: String = ""
    /// Contenu analysé par l'IA, servant de contexte aux nouvelles cartes.
    var contextText: String = ""
    /// La **fiche** du cours, mise en page : c'est ce que l'utilisateur lit après un
    /// import. Elle est encodée en JSON (`CourseSheet`) plutôt que stockée en blocs
    /// SwiftData, parce qu'elle se lit et s'écrit toujours d'un bloc, jamais par morceaux.
    /// Nulle sur un cours importé avant la fiche, ou quand l'analyse a échoué.
    var sheetData: Data?
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
        sheet: CourseSheet? = nil,
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
        self.sheetData = sheet?.encoded()
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

    /// Vrai dès qu'une fiche a été enregistrée. Se lit sans décoder le JSON, donc à
    /// volonté dans une liste.
    var hasSheet: Bool {
        (sheetData?.isEmpty == false)
    }

    /// La fiche décodée, surligneur garanti. Le décodage n'est pas gratuit : un écran la lit
    /// une fois et la garde, il ne l'appelle pas depuis un corps de vue.
    ///
    /// Le surlignage est posé à la lecture et non à l'enregistrement : ce qui est en base
    /// reste ce que le modèle a écrit, et les fiches importées avant que le surligneur existe
    /// se relisent marquées sans qu'on ait à les refaire.
    func decodedSheet() -> CourseSheet? {
        CourseSheet.decode(from: sheetData)?.highlighted()
    }

    func apply(_ sheet: CourseSheet?) {
        sheetData = sheet?.encoded()
    }

    /// Contexte condensé du cours, envoyé à l'IA pour rédiger de nouvelles cartes ou
    /// expliquer un passage. La fiche passe devant le reste : c'est le texte le mieux
    /// organisé dont on dispose sur ce cours.
    func contextSnippet(limit: Int = 6000) -> String {
        var header = "Titre : \(title)\n"
        if let subject, !subject.isEmpty { header += "Matière : \(subject)\n" }
        if !summary.isEmpty { header += summary + "\n\n" }

        let body = contextText.nilIfBlank ?? rawText
        let remaining = max(0, limit - header.count)
        return header + String(body.prefix(remaining))
    }
}
