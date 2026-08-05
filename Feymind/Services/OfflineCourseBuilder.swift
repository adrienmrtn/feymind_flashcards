import Foundation

/// Construit un cours structuré sans appeler l'IA.
/// Sert de repli quand la clé fal n'est pas encore configurée, et pour les aperçus SwiftUI.
enum OfflineCourseBuilder {
    static func build(from rawText: String, hintTitle: String?, sourceName: String?) -> GeneratedCourse {
        let cleaned = TextSanitizer.normalizeExtractedText(rawText)
        let paragraphs = cleaned
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let title = hintTitle?.nilIfBlank
            ?? sourceName?.nilIfBlank
            ?? paragraphs.first.map { String($0.prefix(60)) }
            ?? "Nouveau cours"

        var blocks: [CourseBlockPayload] = []
        blocks.append(.callout(CalloutBlock(
            variant: .info,
            title: "Cours généré hors ligne",
            text: "Ce cours reprend votre texte tel quel. Ajoutez la clé **fal.ai** dans Supabase pour obtenir une mise en forme complète avec schémas et surlignages."
        )))

        var currentSectionCount = 0
        for paragraph in paragraphs.prefix(120) {
            if isLikelyHeading(paragraph) {
                currentSectionCount += 1
                blocks.append(.heading(HeadingBlock(level: currentSectionCount == 1 ? 1 : 2, text: paragraph)))
            } else {
                blocks.append(.paragraph(ParagraphBlock(text: paragraph)))
            }
        }

        let keyPoints = paragraphs
            .filter { $0.count > 40 && !isLikelyHeading($0) }
            .prefix(4)
            .map { String($0.prefix(140)) }

        if !keyPoints.isEmpty {
            blocks.append(.divider)
            blocks.append(.keyPoints(KeyPointsBlock(title: "À retenir", items: Array(keyPoints))))
        }

        return GeneratedCourse(
            title: title,
            subject: nil,
            emoji: "📝",
            summary: String(cleaned.prefix(220)),
            readingMinutes: TextSanitizer.estimatedReadingMinutes(for: cleaned),
            blocks: blocks
        )
    }

    static func buildFlashcards(from course: GeneratedCourse, count: Int) -> [GeneratedFlashcard] {
        var cards: [GeneratedFlashcard] = []

        for block in course.blocks {
            guard cards.count < count else { break }
            switch block {
            case .definition(let definition):
                cards.append(GeneratedFlashcard(front: "Que signifie « \(definition.term) » ?", back: definition.text, hint: nil))
            case .keyPoints(let points):
                for item in points.items where cards.count < count {
                    cards.append(GeneratedFlashcard(front: "Complétez : \(shortened(item))", back: item, hint: nil))
                }
            case .heading(let heading) where heading.level <= 2:
                cards.append(GeneratedFlashcard(front: "Qu'avez-vous retenu sur « \(heading.text) » ?", back: "Reformulez cette partie du cours avec vos mots.", hint: nil))
            default:
                continue
            }
        }

        if cards.isEmpty {
            cards.append(GeneratedFlashcard(
                front: "Résumez « \(course.title) » en trois phrases.",
                back: course.summary.isEmpty ? "Reformulez le cours avec vos mots." : course.summary,
                hint: nil
            ))
        }
        return Array(cards.prefix(count))
    }

    private static func shortened(_ text: String) -> String {
        let words = text.split(separator: " ")
        guard words.count > 6 else { return text }
        return words.prefix(6).joined(separator: " ") + "..."
    }

    private static func isLikelyHeading(_ line: String) -> Bool {
        guard line.count <= 80 else { return false }
        if line.hasSuffix(".") || line.hasSuffix(",") { return false }
        let uppercaseRatio = Double(line.filter(\.isUppercase).count) / Double(max(1, line.filter(\.isLetter).count))
        if uppercaseRatio > 0.6 { return true }
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
        let course = OfflineCourseBuilder.build(from: request.courseContext, hintTitle: request.courseTitle, sourceName: nil)
        return OfflineCourseBuilder.buildFlashcards(from: course, count: request.desiredCount)
    }

    func explain(_ request: ExplainRequest) async throws -> String {
        try await Task.sleep(nanoseconds: 300_000_000)
        return """
        **Mode hors ligne.** Ajoutez la clé fal.ai dans Supabase pour obtenir une vraie explication.

        Passage sélectionné : « \(request.selection.prefix(180)) »
        """
    }

    func generatePodcast(_ request: PodcastGenerationRequest) async throws -> GeneratedPodcast {
        throw AIServiceError.missingProviderKey
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
