import SwiftData
import SwiftUI

// MARK: - La leçon du parcours

/// **Le cours du parcours d'accueil est une leçon**, écrite par la même génération que Home
/// (`LessonBuilder`, `generate-lesson`). Les supports déposés pendant le parcours deviennent la
/// demande ; c'est la leçon offerte, même depuis un PDF ou des photos (voir
/// `LessonCreation.onboarding`).
extension LessonCreation {
    static func onboarding(from setup: DeckSetup) -> LessonCreation {
        let documents = setup.materials.filter(\.isReady).compactMap(\.document)
        let kinds = Set(documents.map { LessonSourceKind(courseSource: $0.source) })
        let source: LessonSourceKind = kinds.count == 1 ? (kinds.first ?? .text) : (kinds.isEmpty ? .text : .mixed)
        return LessonCreation(
            text: setup.combinedText(limit: LessonComposer.maximumCharacters),
            images: setup.combinedImages(limit: LessonComposer.maximumImages),
            source: source,
            sourceName: documents.count == 1 ? documents[0].fileName : nil,
            coverImage: setup.coverImage,
            onboarding: true
        )
    }
}

extension LessonSourceKind {
    /// La provenance d'un support lu, dans les termes de la porte du gratuit.
    init(courseSource: CourseSource) {
        switch courseSource {
        case .pdf: self = .pdf
        case .photo: self = .photo
        case .docx: self = .docx
        case .youtube: self = .youtube
        case .text, .library, .sample, .deck: self = .text
        }
    }
}

// MARK: - Le cours de démonstration, en leçon

extension OnboardingDemoCatalog {
    /// **Le cours de démonstration entre dans la bibliothèque comme une leçon**, sans appel au
    /// modèle : ses chapitres font les cercles Notes, ses QCM les quiz de ses paliers, ses
    /// encadrés « à retenir » la conclusion. Il reste un cours d'exemple (`sample`) : il ne
    /// consomme pas la leçon offerte.
    @MainActor
    static func installLesson(
        _ demo: OnboardingDemoCourse,
        language: ContentLanguage,
        in context: ModelContext
    ) throws -> Course {
        let course = try install(demo, language: language, in: context)
        LessonBuilder.prepareChapters(of: course, in: context)
        LessonBuilder.apply(lessonConversion(of: demo, course: course), to: course, in: context)
        course.lastOpenedAt = Date()
        try context.save()
        return course
    }

    @MainActor
    static func lessonConversion(of demo: OnboardingDemoCourse, course: Course) -> LessonConversion {
        var conversion = LessonBuilder.offlineConversion(of: course)
        conversion.intro = LessonPath.Intro(
            lines: [demo.summary].compactMap(\.nilIfBlank),
            minutes: conversion.intro.minutes
        )
        conversion.takeaways = Array(demo.chapters.flatMap { chapter in
            chapter.blocks.compactMap { block -> String? in
                guard case .callout(_, let text, _) = block else { return nil }
                return text.nilIfBlank
            }
        }.prefix(5))
        for index in conversion.chapters.indices {
            conversion.chapters[index].questions = demo.cards
                .filter { $0.kind == .choice && $0.chapter == index && $0.choices.count >= 2 }
                .map { card in
                    GeneratedQuestion(
                        prompt: card.front,
                        choices: card.choices,
                        answer: min(max(0, card.answerIndex), card.choices.count - 1),
                        why: card.back
                    )
                }
        }
        return conversion
    }
}
