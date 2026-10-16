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

// MARK: - L'aperçu de la leçon

/// **La leçon qu'on vient d'écrire, en chemin** : son icône, son titre, et le parcours entier,
/// cercle par cercle. On regarde, on ne joue pas encore : le chemin s'ouvre pour de vrai dans
/// l'app. Le rond du parcours ouvre les notes du premier thème, puis continue.
struct OnboardingLessonPreview: View {
    let course: Course

    @Environment(LessonBuilder.self) private var builder
    @State private var session: LessonSession

    init(course: Course) {
        self.course = course
        _session = State(initialValue: LessonSession(course: course))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 12) {
                    MicaboIconView(icon: course.icon, size: 88)
                        .padding(.top, 36)
                    Text(course.title)
                        .font(MicaboFont.title)
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    Text(L10n.t("lesson.onboarding.previewSub", locale: .resolved()))
                        .font(MicaboFont.ui(15, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                        .padding(.bottom, 28)
                    PathMapView(
                        session: session,
                        tone: course.tone,
                        width: geometry.size.width,
                        onOpen: { _ in },
                        onRetry: { _ in }
                    )
                    .allowsHitTesting(false)
                }
                .padding(.bottom, MicaboLayout.bottomBarClearance)
            }
            .scrollIndicators(.hidden)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .onChange(of: builder.writing) { _, _ in session.reload() }
    }
}

/// Les notes d'un thème, ouvertes depuis l'aperçu : la fiche riche pour le cours de
/// démonstration, les notes de la leçon sinon. « Continuer » reprend le parcours.
struct OnboardingThemeReader: View {
    let chapter: Chapter
    let demo: DemoChapter?
    let onContinue: () -> Void

    private var tone: LessonTone { chapter.course?.tone ?? .blue }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ThemeHeader(chapter: chapter)
                    if chapter.status == .pending {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(L10n.t("lesson.notes.writing", locale: .resolved()))
                                .font(MicaboFont.ui(15, weight: .bold))
                                .foregroundStyle(MicaboColor.inkSecondary)
                        }
                    } else if let demo {
                        DemoSheetView(blocks: demo.blocks, tint: tone.ink)
                    } else {
                        ThemeBody(chapter: chapter, tone: tone)
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            Button(L10n.t("lesson.create.continue", locale: .resolved()), action: onContinue)
                .buttonStyle(LessonPrimaryButtonStyle())
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 12)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
    }
}
