import Foundation

/// **Chercher dans toutes ses leçons, pas seulement dans leurs titres** (lot 7).
///
/// La recherche de l'onglet Leçons lisait le titre, la matière et le résumé. Un élève qui
/// cherche « mitochondrie » ou « Bismarck » pense au contenu : une carte, un thème, une page
/// de ses supports. L'index est construit **sur l'appareil**, une fois quand la recherche
/// commence, et chaque leçon y a son texte replié (sans accents ni majuscules) : « evolution »
/// trouve « Évolution », « krebs » trouve « Krebs ». Rien ne part au serveur.
enum LessonSearch {
    /// Ce qu'on lit d'un support importé : assez pour retrouver un mot, sans recopier un
    /// manuel entier dans la mémoire.
    static let sourceCharacters = 20_000

    /// Le texte replié, pour comparer sans accents ni casse, dans toutes les écritures.
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
    }

    /// Tout ce qu'une leçon contient, replié : titre, matière, résumé, thèmes, cartes (recto,
    /// verso, indice) et le début de ses supports.
    static func entry(
        title: String,
        subject: String?,
        summary: String,
        chapters: [String],
        cards: [(front: String, back: String, hint: String?)],
        source: String
    ) -> String {
        var parts: [String] = [title, subject ?? "", summary]
        parts += chapters
        for card in cards {
            parts.append(card.front)
            parts.append(card.back)
            if let hint = card.hint { parts.append(hint) }
        }
        parts.append(String(source.prefix(sourceCharacters)))
        return fold(parts.filter { !$0.isEmpty }.joined(separator: "\n"))
    }

    static func entry(for course: Course) -> String {
        entry(
            title: course.title,
            subject: course.subject,
            summary: course.summary,
            chapters: course.orderedChapters.map(\.title),
            cards: course.cards.map { (front: $0.front, back: $0.back, hint: $0.hint) },
            source: course.rawText
        )
    }

    /// L'index de toutes les leçons, par identifiant.
    static func index(_ courses: [Course]) -> [UUID: String] {
        var index: [UUID: String] = [:]
        for course in courses {
            index[course.id] = entry(for: course)
        }
        return index
    }

    /// Les mots cherchés, repliés. Une recherche de plusieurs mots les veut tous, dans
    /// n'importe quel ordre : « guerre froide » trouve « la Guerre froide » comme « froide
    /// guerre ».
    static func terms(_ query: String) -> [String] {
        fold(query)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    static func matches(_ entry: String?, query: String) -> Bool {
        guard let entry else { return false }
        let wanted = Self.terms(query)
        guard !wanted.isEmpty else { return true }
        return wanted.allSatisfy { entry.contains($0) }
    }
}
