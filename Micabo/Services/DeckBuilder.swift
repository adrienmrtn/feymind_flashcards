import Foundation
import SwiftData

/// **Construire un deck entier, d'un bout à l'autre.**
///
/// L'import d'avant s'arrêtait à la fiche : les cartes se demandaient ensuite, depuis le
/// cours, par un second geste. C'était défendable quand on importait un chapitre ; ça ne
/// l'est plus quand on dépose tout son matériel de révision d'une matière et qu'on attend un
/// plan de travail. L'étudiant qui a répondu à sept questions et regardé un écran de
/// construction n'a pas envie d'apprendre, à l'arrivée, qu'il reste un bouton à presser.
///
/// La construction est donc une seule opération, et elle est **progressive** : chaque étape
/// est annoncée pendant qu'elle se fait, parce qu'elle dure. Écrire une fiche sur quarante
/// pages prend une vingtaine de secondes, et les cartes autant ; un écran qui tournerait sans
/// rien dire pendant quarante secondes se lit comme un plantage.
///
/// **Ce qui est enregistré l'est dès que ça existe.** Le cours est écrit en base avant que
/// les cartes ne soient demandées : si la génération de cartes échoue — le réseau tombe, le
/// modèle refuse —, l'étudiant garde sa fiche et ses chapitres, et l'écran du deck lui
/// propose d'écrire les cartes. Tout annuler parce que la seconde moitié a échoué lui ferait
/// reperdre les quarante pages qu'il vient de déposer.
enum DeckBuilder {
    /// Où en est la construction, pour l'écran qui la regarde.
    enum Stage: Equatable {
        case reading
        case writingSheet
        case splitting
        case writingCards
        case done

        var captionKey: String {
            switch self {
            case .reading: "ios.deckBuild.reading"
            case .writingSheet: "ios.deckBuild.sheet"
            case .splitting: "ios.deckBuild.chapters"
            case .writingCards: "ios.deckBuild.cards"
            case .done: "ios.deckBuild.done"
            }
        }

        /// La part du chemin parcourue, pour la jauge. Les poids ne sont pas égaux parce que
        /// les étapes ne durent pas pareil : l'écriture de la fiche et celle des cartes
        /// prennent chacune une vingtaine de secondes, le découpage est instantané. Une
        /// jauge qui avance par quarts sur des étapes inégales s'arrête visiblement.
        var progress: Double {
            switch self {
            case .reading: 0.06
            case .writingSheet: 0.45
            case .splitting: 0.52
            case .writingCards: 0.95
            case .done: 1
            }
        }
    }

    struct Outcome {
        var course: Course
        var cardCount: Int
        /// La génération des cartes a échoué, mais le cours est là. L'écran du deck le dira.
        var cardFailure: String?
    }

    /// **Combien de cartes pour ce deck.**
    ///
    /// Entre dix et cent trente, selon la densité du contenu. Le rapport est volontairement
    /// prudent : une carte pour huit cents caractères de fiche. Un cours de trente mille
    /// caractères donne donc une quarantaine de cartes, ce qui est une semaine de travail
    /// réel — pas cent trente, ce qui serait un mur.
    ///
    /// Le plafond n'est pas une précaution de coût, c'est une précaution d'usage : au-delà
    /// de cent trente cartes sur une matière, le deck ne se finit pas, et un deck qui ne se
    /// finit pas ne se commence pas.
    static let cardBounds = 10...130

    static func cardCount(forContextLength length: Int, chapters: Int) -> Int {
        let fromText = Int((Double(length) / 800).rounded())
        // Un plancher par chapitre : un plan de neuf parties dont trois n'ont aucune carte
        // donne trois pourcentages à zéro qui ne bougeront jamais.
        let fromPlan = chapters * 4
        return min(cardBounds.upperBound, max(cardBounds.lowerBound, max(fromText, fromPlan)))
    }

    /// Répartit un volume total entre les trois formats.
    ///
    /// Le recto verso domine parce que c'est le format qui marche sur n'importe quelle
    /// matière ; le QCM et le texte à trou complètent. Ils partent **dans la même session**
    /// que les autres — un paquet de QCM à part se réviserait comme un questionnaire, pas
    /// comme une révision.
    static func quota(total: Int) -> QuestionQuota {
        let choice = total / 5
        let cloze = total / 6
        return QuestionQuota(basic: max(1, total - choice - cloze), cloze: cloze, choice: choice)
    }

    /// Construit le deck et rend le cours créé.
    ///
    /// `onStage` est appelé sur l'acteur principal à chaque changement d'étape : c'est ce
    /// que l'écran d'attente affiche.
    @MainActor
    static func build(
        _ setup: DeckSetup,
        using service: any AIService,
        in modelContext: ModelContext,
        onStage: @MainActor (Stage) -> Void = { _ in }
    ) async throws -> Outcome {
        onStage(.writingSheet)

        let generated = try await writeSheet(setup, using: service)

        let course = try CourseRepository.save(
            generated,
            source: setup.courseSource,
            rawText: setup.source == .materials ? setup.combinedText() : "",
            fileName: setup.materials.first(where: \.isReady)?.document?.fileName,
            coverImageData: setup.coverImage,
            in: modelContext
        )
        // La matière est connue avant la génération, ici : l'étudiant vient de la choisir.
        // À l'import ordinaire elle est devinée, et c'est la seule raison pour laquelle le
        // modèle la cherchait.
        if let subject = setup.subject?.nilIfBlank {
            course.subject = subject
        }
        // Le nom saisi passe devant celui que le modèle a trouvé : c'est celui sous lequel
        // l'étudiant cherchera son deck.
        if let name = setup.name.nilIfBlank {
            course.title = name
        }

        onStage(.splitting)
        ChapterBuilder.migrate(course, in: modelContext)
        try? modelContext.save()

        onStage(.writingCards)
        var cardCount = 0
        var cardFailure: String?
        do {
            let cards = try await writeCards(for: course, using: service, in: modelContext)
            cardCount = cards.count
        } catch {
            // Le cours est déjà en base : on ne défait rien. L'écran du deck proposera
            // d'écrire les cartes, et le bouton existe déjà pour ça.
            cardFailure = error.localizedDescription
        }

        if let deadline = setup.deadline {
            createExam(for: course, setup: setup, deadline: deadline, in: modelContext)
        }

        try? modelContext.save()
        onStage(.done)

        Analytics.track(.courseImported, [
            "source": .text(setup.courseSource.rawValue),
            "deck": .flag(true),
            "generated": .flag(setup.source == .generated),
            "cards": .number(Double(cardCount)),
        ])

        return Outcome(course: course, cardCount: cardCount, cardFailure: cardFailure)
    }

    // MARK: - La fiche

    @MainActor
    private static func writeSheet(
        _ setup: DeckSetup,
        using service: any AIService
    ) async throws -> GeneratedCourse {
        let text = setup.source == .materials ? setup.combinedText() : ""

        let request = CourseGenerationRequest(
            rawText: text,
            pageImages: setup.source == .materials ? setup.combinedImages() : [],
            hintTitle: setup.name.nilIfBlank,
            sourceName: setup.materials.first(where: \.isReady)?.document?.fileName,
            studyLevel: OnboardingPreferences.studyLevel,
            country: OnboardingPreferences.schoolingCountry,
            language: OnboardingPreferences.contentLanguage,
            // Un deck couvre une matière entière, pas un chapitre : il lui faut la fiche
            // longue. C'est elle qui donnera assez de parties pour que le plan ait un sens.
            sheetLength: .deep,
            sheetBlocks: SheetLength.deep.defaultBlocks,
            subject: setup.subject?.nilIfBlank,
            sourceKind: setup.courseSource,
            // **Le sujet quand il n'y a pas de document.** C'est lui qui fait basculer la
            // fonction du mode « lis ce document » au mode « écris le cours ». Vide, il
            // demande tout le programme de la matière au niveau de l'étudiant.
            topic: setup.source == .generated ? (setup.topic.nilIfBlank ?? "") : nil
        )

        do {
            return try await service.generateCourse(request)
        } catch let error as AIServiceError where error.allowsOfflineFallback && !text.isEmpty {
            // Il y a un document : plutôt que de renvoyer l'étudiant les mains vides après
            // sept questions, on taille la fiche dans son texte. Elle est moins bonne, elle
            // est vraie. Sans document, il n'y a rien à tailler et l'erreur remonte.
            return OfflineCourseBuilder.build(
                from: text,
                hintTitle: setup.name.nilIfBlank,
                sourceName: setup.materials.first(where: \.isReady)?.document?.fileName
            )
        }
    }

    // MARK: - Les cartes

    @MainActor
    private static func writeCards(
        for course: Course,
        using service: any AIService,
        in modelContext: ModelContext
    ) async throws -> [Flashcard] {
        let context = course.contextSnippet(limit: 30_000)
        let chapters = course.orderedChapters
        let total = cardCount(forContextLength: context.count, chapters: chapters.count)

        let request = FlashcardGenerationRequest(
            courseTitle: course.title,
            courseContext: context,
            existingFronts: course.cards.map(\.front),
            quota: quota(total: total),
            subject: course.subject,
            language: OnboardingPreferences.contentLanguage,
            chapterTitles: chapters.map(\.title)
        )

        let generated = try await service.generateFlashcards(request)
        let inserted = try CourseRepository.addFlashcards(generated, to: course, in: modelContext)

        if SubjectHeuristics.isLanguage(subject: course.subject, title: course.title) {
            _ = try? CourseRepository.addReverseCards(for: course, in: modelContext)
        }
        return inserted
    }

    // MARK: - L'échéance

    /// **L'épreuve n'est pas replanifiée.**
    ///
    /// Elle est créée, datée, et marquée comme prise en compte — c'est ce que lit
    /// `ExamDeadlines` pour faire passer les cartes de ce deck devant les autres. Ce qu'elle
    /// ne fait **pas**, et ce que l'ancien chemin faisait, c'est réécrire l'échéance de
    /// chaque carte pour les étaler sur un calendrier de passages. La date ne touche qu'au
    /// nombre de cartes neuves par jour : voir `DeckPace`.
    @MainActor
    private static func createExam(
        for course: Course,
        setup: DeckSetup,
        deadline: Date,
        in modelContext: ModelContext
    ) {
        let exam = Exam(
            name: setup.resolvedTitle,
            date: deadline,
            courseIDs: [course.id],
            targetScore: setup.targetScore,
            kind: setup.purpose?.examKind ?? .exam,
            // L'auto-évaluation, rangée là où l'app sait déjà dire « je pars de loin ». Rien
            // ne la lit pour l'instant, et c'est ce qui était annoncé : elle est décorative.
            startingPoint: startingPoint(for: setup.confidence)
        )
        exam.isPlanned = true
        exam.plannedAt = Date()
        modelContext.insert(exam)
    }

    private static func startingPoint(for confidence: Double) -> ExamStartingPoint {
        switch confidence {
        case ..<0.33: .cold
        case ..<0.72: .seen
        default: .solid
        }
    }
}
