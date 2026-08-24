import Foundation

/// Résultat de l'analyse d'un import, avant enregistrement.
///
/// L'analyse produit deux choses de nature différente. La **fiche** (`sheet`) est mise en
/// page et destinée à être lue. Le **contexte** (`contextText`) est le même contenu à plat,
/// destiné au modèle quand il faudra écrire des cartes ou expliquer un passage : aucune
/// mise en forme, une notion par ligne. Le serveur renvoie les deux, mais si le contexte
/// manque, il est reconstitué depuis la fiche plutôt que d'être perdu.
struct GeneratedCourse: Codable {
    var title: String
    var subject: String?
    var emoji: String?
    var summary: String
    /// La fiche mise en page. Absente quand la génération a été faite hors ligne, ou
    /// quand le serveur déployé est une version antérieure à la fiche.
    var sheet: CourseSheet?
    /// Contenu du document mis à plat, envoyé au modèle avec les demandes de cartes.
    var contextText: String

    init(
        title: String,
        subject: String? = nil,
        emoji: String? = nil,
        summary: String,
        sheet: CourseSheet? = nil,
        contextText: String
    ) {
        self.title = title
        self.subject = subject
        self.emoji = emoji
        self.summary = summary
        self.sheet = sheet
        self.contextText = contextText
    }

    private enum CodingKeys: String, CodingKey {
        case title, subject, emoji, summary, sheet, contextText, blocks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = (try? container.decode(String.self, forKey: .title)) ?? "Cours sans titre"
        subject = try? container.decodeIfPresent(String.self, forKey: .subject)
        emoji = try? container.decodeIfPresent(String.self, forKey: .emoji)
        summary = (try? container.decode(String.self, forKey: .summary)) ?? ""

        let decodedSheet = try? container.decodeIfPresent(CourseSheet.self, forKey: .sheet)
        sheet = (decodedSheet?.isEmpty == false) ? decodedSheet : nil

        if let text = try? container.decode(String.self, forKey: .contextText), !text.isEmpty {
            contextText = text
        } else if let sheet {
            // Le serveur n'a pas envoyé la version à plat : la fiche la contient déjà.
            contextText = sheet.plainText()
        } else if let blocks = try? container.decode(JSONValue.self, forKey: .blocks) {
            // Format d'avant la fiche : le serveur renvoyait une mise en page libre dont
            // on ne gardait que le texte. On reste tolérant.
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
        try container.encodeIfPresent(sheet, forKey: .sheet)
        try container.encode(contextText, forKey: .contextText)
    }
}
