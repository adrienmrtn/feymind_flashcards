import Foundation

/// Analyse un import sans appeler l'IA.
/// Sert de repli quand la clé fal n'est pas encore configurée, et pour les aperçus SwiftUI.
enum OfflineCourseBuilder {
    static func build(from rawText: String, hintTitle: String?, sourceName: String?) -> GeneratedCourse {
        let cleaned = TextSanitizer.normalizeExtractedText(rawText)
        let lines = usableLines(of: cleaned)

        let title = hintTitle?.nilIfBlank
            ?? sourceName?.nilIfBlank
            ?? lines.first.map { String($0.prefix(60)) }
            ?? "Nouveau cours"

        return GeneratedCourse(
            title: title,
            emoji: "📝",
            summary: String(cleaned.prefix(200)),
            sheet: OfflineSheetBuilder.build(from: cleaned, title: title),
            contextText: String(cleaned.prefix(12_000))
        )
    }

    static func buildFlashcards(from course: GeneratedCourse, count: Int) -> [GeneratedFlashcard] {
        let lines = usableLines(of: course.contextText)
        var cards: [GeneratedFlashcard] = []
        var currentSection: String?

        for line in lines {
            guard cards.count < count else { break }

            if isLikelyHeading(line) {
                currentSection = line
                cards.append(GeneratedFlashcard(
                    front: "Qu'as-tu retenu sur « \(line) » ?",
                    back: "Reformule cette partie du cours avec tes mots.",
                    hint: nil
                ))
            } else if line.count >= 60 {
                cards.append(GeneratedFlashcard(
                    front: "Complète : \(shortened(line))",
                    back: line,
                    hint: currentSection
                ))
            }
        }

        if cards.isEmpty {
            cards.append(GeneratedFlashcard(
                front: "Résume « \(course.title) » en trois phrases.",
                back: course.summary.isEmpty ? "Reformule le cours avec tes mots." : course.summary,
                hint: nil
            ))
        }
        return Array(cards.prefix(count))
    }

    /// Explication d'un passage sans appel réseau : on ne fabrique pas de savoir, on rend
    /// le passage du cours où le terme apparaît. Sert aux aperçus, et c'est mieux qu'une
    /// alerte vide si le réseau lâche.
    static func explain(_ request: SelectionExplanationRequest) -> SelectionExplanation {
        let selection = SheetSelection.trimmed(request.selection)
        let sentences = request.courseContext
            .components(separatedBy: CharacterSet(charactersIn: ".\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 20 }

        let matching = sentences.filter { $0.localizedCaseInsensitiveContains(selection) }

        guard let first = matching.first else {
            return SelectionExplanation(
                headline: "« \(selection) » n'a pas pu être expliqué hors ligne.",
                body: "Micabo n'a pas trouvé ce passage dans le cours et n'a pas pu joindre l'IA. Vérifie ta connexion, puis réessaie.",
                example: nil,
                watchOut: nil,
                card: nil
            )
        }

        return SelectionExplanation(
            headline: "**\(selection)** apparaît dans « \(request.courseTitle) ».",
            body: matching.prefix(3).joined(separator: ". ") + ".",
            example: nil,
            watchOut: nil,
            card: GeneratedFlashcard(front: "Que dit ton cours sur « \(selection) » ?", back: first + ".")
        )
    }

    private static func usableLines(of text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 12 }
    }

    private static func shortened(_ text: String) -> String {
        let words = text.split(separator: " ")
        guard words.count > 6 else { return text }
        return words.prefix(6).joined(separator: " ") + "..."
    }

    private static func isLikelyHeading(_ line: String) -> Bool {
        guard line.count <= 80 else { return false }
        if line.hasSuffix(".") || line.hasSuffix(",") { return false }
        let letters = max(1, line.filter(\.isLetter).count)
        if Double(line.filter(\.isUppercase).count) / Double(letters) > 0.6 { return true }
        return line.count <= 60 && line.split(separator: " ").count <= 9
    }
}

/// Service utilisé pour les aperçus et le repli hors ligne.
struct OfflineAIService: AIService {
    func generateCourse(_ request: CourseGenerationRequest) async throws -> GeneratedCourse {
        try await Task.sleep(nanoseconds: 400_000_000)
        return OfflineCourseBuilder.build(
            from: request.rawText,
            hintTitle: request.hintTitle,
            sourceName: request.sourceName
        )
    }

    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard] {
        try await Task.sleep(nanoseconds: 300_000_000)
        let course = OfflineCourseBuilder.build(
            from: request.courseContext,
            hintTitle: request.courseTitle,
            sourceName: nil
        )
        return OfflineCourseBuilder.buildFlashcards(from: course, count: request.quota.total)
    }

    func explain(_ request: SelectionExplanationRequest) async throws -> SelectionExplanation {
        try await Task.sleep(nanoseconds: 300_000_000)
        return OfflineCourseBuilder.explain(request)
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
