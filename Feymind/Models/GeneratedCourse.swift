import Foundation

/// Résultat de l'analyse d'un import, avant enregistrement.
/// Le contenu n'est jamais mis en page : il sert uniquement de contexte pour rédiger les cartes.
struct GeneratedCourse: Codable {
    var title: String
    var subject: String?
    var emoji: String?
    var summary: String
    /// Contenu du document mis à plat, envoyé au modèle avec les demandes de flashcards.
    var contextText: String

    init(
        title: String,
        subject: String? = nil,
        emoji: String? = nil,
        summary: String,
        contextText: String
    ) {
        self.title = title
        self.subject = subject
        self.emoji = emoji
        self.summary = summary
        self.contextText = contextText
    }

    private enum CodingKeys: String, CodingKey {
        case title, subject, emoji, summary, contextText, blocks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? container.decode(String.self, forKey: .title)) ?? "Cours sans titre"
        subject = try? container.decodeIfPresent(String.self, forKey: .subject)
        emoji = try? container.decodeIfPresent(String.self, forKey: .emoji)
        summary = (try? container.decode(String.self, forKey: .summary)) ?? ""

        if let text = try? container.decode(String.self, forKey: .contextText), !text.isEmpty {
            contextText = text
        } else if let blocks = try? container.decode(JSONValue.self, forKey: .blocks) {
            // Le serveur peut renvoyer une mise en page structurée : on n'en garde que le texte.
            contextText = blocks.textLines().joined(separator: "\n")
        } else {
            contextText = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subject, forKey: .subject)
        try container.encodeIfPresent(emoji, forKey: .emoji)
        try container.encode(summary, forKey: .summary)
        try container.encode(contextText, forKey: .contextText)
    }
}
