import Foundation

/// Petites déductions à partir de la matière et du titre d'un cours.
enum SubjectHeuristics {
    private static let languageKeywords = [
        "anglais", "english", "espagnol", "spanish", "allemand", "deutsch", "italien",
        "portugais", "russe", "japonais", "chinois", "mandarin", "coreen", "arabe",
        "latin", "grec", "hebreu", "neerlandais", "suedois", "langue", "langues",
        "vocabulaire", "conjugaison", "grammaire"
    ]

    /// Vrai pour un cours de langue. Ces cours gagnent à être révisés dans les deux sens,
    /// et à porter un son : c'est ce qui déclenche la génération des cartes inverses.
    static func isLanguage(subject: String?, title: String) -> Bool {
        let haystack = [subject ?? "", title]
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        return languageKeywords.contains { haystack.contains($0) }
    }
}
