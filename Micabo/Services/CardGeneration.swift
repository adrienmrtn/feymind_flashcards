import Foundation
import SwiftData

/// Écrire des cartes pour un cours déjà fiché.
///
/// Depuis que l'import s'arrête à la fiche, la génération de cartes est une action à part
/// entière, lancée depuis le cours ou depuis l'écran des cartes. Les deux passent par ici,
/// et c'est le seul endroit qui connaît le repli hors ligne et la règle des cartes
/// inverses : deux écrans qui écriraient chacun leur version finiraient par ne plus
/// produire les mêmes cartes.
enum CardGeneration {
    struct Options {
        var quota: QuestionQuota = .default

        /// Ce que les réglages retiennent d'une génération à l'autre.
        static var remembered: Options {
            Options(quota: QuestionQuotaPreferences.current)
        }
    }

    /// La fiche est le meilleur contexte dont on dispose : elle est déjà organisée, et
    /// c'est exactement le contenu que l'utilisateur a sous les yeux quand il demande des
    /// cartes.
    static func context(for course: Course, limit: Int = 30_000) -> String {
        course.contextSnippet(limit: limit)
    }

    @MainActor
    @discardableResult
    static func run(
        for course: Course,
        options: Options = .remembered,
        using service: any AIService,
        in modelContext: ModelContext
    ) async throws -> [Flashcard] {
        let quota = options.quota.clamped()
        let request = FlashcardGenerationRequest(
            courseTitle: course.title,
            courseContext: context(for: course),
            existingFronts: course.cards.map(\.front),
            quota: quota,
            // Une carte de droit ne demande pas la même chose qu'une carte de langue : la
            // matière du cours décide de ce qu'il faut interroger.
            subject: course.subject,
            language: OnboardingPreferences.contentLanguage
        )

        var generated: [GeneratedFlashcard]
        do {
            generated = try await service.generateFlashcards(request)
        } catch let error as AIServiceError where error.allowsOfflineFallback {
            // La fiche est là : plutôt que de renvoyer l'utilisateur les mains vides, on
            // taille des cartes dans son texte. Elles sont moins bonnes, elles sont
            // vraies, et il peut les corriger.
            generated = OfflineCourseBuilder.buildFlashcards(
                from: OfflineCourseBuilder.build(
                    from: context(for: course),
                    hintTitle: course.title,
                    sourceName: nil
                ),
                count: quota.total
            )
        }

        let inserted = try CourseRepository.addFlashcards(generated, to: course, in: modelContext)
        guard !inserted.isEmpty else {
            throw CardGenerationError.noUsableCards(courseTitle: course.title)
        }

        // Les langues se révisent dans les deux sens : la carte inverse est créée d'office,
        // avec sa propre planification.
        if SubjectHeuristics.isLanguage(subject: course.subject, title: course.title) {
            _ = try? CourseRepository.addReverseCards(for: course, in: modelContext)
        }

        return inserted
    }
}

enum CardGenerationError: LocalizedError {
    case noUsableCards(courseTitle: String)

    var errorDescription: String? {
        switch self {
        case .noUsableCards(let title):
            "Rien dans « \(title) » n'a pu être transformé en carte. Ouvre la fiche pour vérifier son contenu, ou écris une carte à la main."
        }
    }
}

extension AIServiceError {
    /// Les pannes derrière lesquelles il reste raisonnable de construire des cartes sans
    /// IA. Un texte vide, lui, ne donnera rien de plus hors ligne.
    var allowsOfflineFallback: Bool {
        switch self {
        case .notConfigured, .missingProviderKey, .network, .server, .invalidResponse:
            true
        case .emptySource:
            false
        }
    }
}
