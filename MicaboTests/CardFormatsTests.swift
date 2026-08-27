import CoreGraphics
import SwiftData
import XCTest
@testable import Micabo

/// Les trois formats ajoutés : formules, occlusion d'image, sens inverse.
final class CardFormatsTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Course.self,
            Flashcard.self,
            ReviewLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    private func makeCourse(title: String = "Cours", subject: String? = nil, rawText: String = "") throws -> Course {
        try CourseRepository.save(
            GeneratedCourse(title: title, subject: subject, emoji: "📘", summary: "", contextText: rawText),
            source: .text,
            rawText: rawText,
            in: context
        )
    }

    // MARK: - Formules

    func testTextWithoutFormulaIsLeftAlone() {
        let segments = FormulaRenderer.segments(of: "Une phrase normale.")

        XCTAssertEqual(segments, [FormulaRenderer.Segment(text: "Une phrase normale.", isMath: false)])
        XCTAssertFalse(FormulaRenderer.containsFormula("Une phrase normale."))
    }

    func testFormulaIsIsolatedAndTransposed() {
        let segments = FormulaRenderer.segments(of: "L'énergie vaut $E = mc^2$ toujours.")

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0], FormulaRenderer.Segment(text: "L'énergie vaut ", isMath: false))
        XCTAssertEqual(segments[1], FormulaRenderer.Segment(text: "E = mc²", isMath: true))
        XCTAssertEqual(segments[2], FormulaRenderer.Segment(text: " toujours.", isMath: false))
    }

    func testSubscriptsSuperscriptsAndSymbols() {
        XCTAssertEqual(FormulaRenderer.plain("H_2O"), "H₂O")
        XCTAssertEqual(FormulaRenderer.plain("x^{10}"), "x¹⁰")
        XCTAssertEqual(FormulaRenderer.plain("\\Delta v = a \\times t"), "Δv = a × t")
        XCTAssertEqual(FormulaRenderer.plain("\\alpha + \\beta \\leq \\pi"), "α + β ≤ π")
    }

    func testIntegralIsNotEatenByTheMembershipSymbol() {
        XCTAssertEqual(FormulaRenderer.plain("\\int"), "∫")
        XCTAssertEqual(FormulaRenderer.plain("\\infty"), "∞")
        XCTAssertEqual(FormulaRenderer.plain("x \\in \\mathbb{R}"), "x ∈ ℝ")
    }

    func testFractionsAndRoots() {
        XCTAssertEqual(FormulaRenderer.plain("\\frac{1}{2}"), "1/2")
        XCTAssertEqual(FormulaRenderer.plain("\\frac{a + b}{c}"), "(a + b)/c")
        XCTAssertEqual(FormulaRenderer.plain("\\sqrt{2}"), "√2")
    }

    func testUnbalancedDelimiterStaysLiteral() {
        let segments = FormulaRenderer.segments(of: "Le prix est de 12 $ environ")

        XCTAssertFalse(segments.contains { $0.isMath })
    }

    func testStrippedTextDropsTheDelimiters() {
        XCTAssertEqual(FormulaRenderer.stripped("Calcule $x^2$ ici"), "Calcule x² ici")
    }

    func testBareLatexCommandsInPlainTextBecomeSymbols() {
        XCTAssertEqual(FormulaRenderer.stripped("1914 \\rightarrow 1918"), "1914 → 1918")
        XCTAssertEqual(FormulaRenderer.symbolsOnly("A \\to B"), "A → B")
    }

    // MARK: - Occlusion

    func testOneCardPerNamedZone() throws {
        let course = try makeCourse()
        let image = Data([0x01, 0x02, 0x03])
        let zones = [
            OcclusionZone(rect: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2), label: "Fémur"),
            OcclusionZone(rect: CGRect(x: 0.5, y: 0.5, width: 0.2, height: 0.2), label: "Tibia"),
            OcclusionZone(rect: CGRect(x: 0.8, y: 0.8, width: 0.1, height: 0.1), label: "   ")
        ]

        let cards = try CourseRepository.addOcclusionCards(zones, image: image, to: course, in: context)

        XCTAssertEqual(cards.count, 2, "Une zone sans nom ne donne pas de carte")
        XCTAssertEqual(cards.map(\.back), ["Fémur", "Tibia"])
        XCTAssertTrue(cards.allSatisfy { $0.kind == .occlusion })
        XCTAssertTrue(cards.allSatisfy { $0.isOcclusion })
        XCTAssertTrue(cards.allSatisfy { $0.imageData == image })
        XCTAssertEqual(Set(cards.compactMap(\.groupID)).count, 1, "Les zones d'un même schéma partagent un groupe")
        XCTAssertEqual(cards[0].maskRect.origin.x, 0.1, accuracy: 0.0001)
        XCTAssertEqual(cards[1].maskRect.size.height, 0.2, accuracy: 0.0001)
    }

    func testOcclusionCardsAreScheduledIndependently() throws {
        let course = try makeCourse()
        let cards = try CourseRepository.addOcclusionCards(
            [
                OcclusionZone(rect: CGRect(x: 0, y: 0, width: 0.2, height: 0.2), label: "A"),
                OcclusionZone(rect: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2), label: "B")
            ],
            image: Data([0x01]),
            to: course,
            in: context
        )

        XCTAssertEqual(Set(cards.map(\.id)).count, 2)
        XCTAssertTrue(cards.allSatisfy { $0.state == .new })
    }

    // MARK: - Textes à trou

    func testClozeCardKeepsItsGapEvenWrittenWithUnderscores() throws {
        let course = try makeCourse()
        let cards = try CourseRepository.addFlashcards(
            [GeneratedFlashcard(front: "La capitale du Pérou est ___.", back: "Lima", kind: "cloze")],
            to: course,
            in: context
        )

        let card = try XCTUnwrap(cards.first)
        XCTAssertEqual(card.kind, .cloze)
        XCTAssertEqual(card.format, .cloze)
        XCTAssertEqual(card.front, "La capitale du Pérou est \(ClozeGap.marker).", "Les tirets bas sont mangés par le nettoyage : le trou doit être posé avant")
    }

    func testClozeWithoutAGapFallsBackOnTheBasicFormat() throws {
        let course = try makeCourse()
        let cards = try CourseRepository.addFlashcards(
            [GeneratedFlashcard(front: "Quelle est la capitale du Pérou ?", back: "Lima", kind: "cloze")],
            to: course,
            in: context
        )

        XCTAssertEqual(cards.first?.kind, .basic, "Un texte à trou sans trou n'est qu'une carte recto verso")
    }

    // MARK: - QCM

    func testMultipleChoiceCardKeepsItsChoicesAndAnswer() throws {
        let course = try makeCourse()
        let cards = try CourseRepository.addFlashcards(
            [
                GeneratedFlashcard(
                    front: "Où se déroule le cycle de Calvin ?",
                    back: "Dans le stroma du chloroplaste.",
                    kind: "choice",
                    choices: ["Dans les thylakoïdes", "Dans le stroma", "Dans la mitochondrie"],
                    answerIndex: 1
                )
            ],
            to: course,
            in: context
        )

        let card = try XCTUnwrap(cards.first)
        XCTAssertEqual(card.format, .choice)
        XCTAssertTrue(card.isMultipleChoice)
        XCTAssertEqual(card.choices.count, 3)
        XCTAssertEqual(card.correctChoice, "Dans le stroma")
    }

    func testAnswerIsRecoveredFromTheBackWhenTheIndexIsMissingOrWrong() throws {
        let course = try makeCourse()
        let cards = try CourseRepository.addFlashcards(
            [
                GeneratedFlashcard(front: "Capitale du Pérou ?", back: "Lima", kind: "choice", choices: ["Quito", "Lima", "La Paz"]),
                GeneratedFlashcard(front: "Capitale du Chili ?", back: "Santiago", kind: "choice", choices: ["Santiago", "Lima"], answerIndex: 9)
            ],
            to: course,
            in: context
        )

        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards[0].correctChoice, "Lima")
        XCTAssertEqual(cards[1].correctChoice, "Santiago")
    }

    func testAQcmThatCannotStandUpBecomesABasicCard() throws {
        let course = try makeCourse()
        let cards = try CourseRepository.addFlashcards(
            [
                // Une seule proposition, et un doublon qui n'en fait toujours qu'une.
                GeneratedFlashcard(front: "Capitale du Pérou ?", back: "Lima", kind: "choice", choices: ["Lima", "Lima"], answerIndex: 0),
                // Aucune proposition ne reprend le verso, et l'index est absent.
                GeneratedFlashcard(front: "Capitale du Chili ?", back: "Santiago", kind: "choice", choices: ["Quito", "Lima"])
            ],
            to: course,
            in: context
        )

        XCTAssertEqual(cards.map(\.format), [.basic, .basic])
        XCTAssertFalse(cards.contains(where: \.isMultipleChoice))
        XCTAssertEqual(cards.map(\.back), ["Lima", "Santiago"], "La question et la réponse restent bonnes : on ne jette pas la carte")
    }

    func testTheGeneratedKindIsIgnoredWhenItIsNotAWrittenFormat() {
        XCTAssertEqual(GeneratedFlashcard(front: "a", back: "b").resolvedKind, .basic)
        XCTAssertEqual(GeneratedFlashcard(front: "a", back: "b", kind: "n'importe quoi").resolvedKind, .basic)
        XCTAssertEqual(
            GeneratedFlashcard(front: "a", back: "b", kind: "occlusion").resolvedKind,
            .basic,
            "Une occlusion se dessine sur une image, elle ne se génère pas depuis du texte"
        )
    }

    // MARK: - Combien de cartes, par format

    func testOnlyTheRequestedFormatsAreAnnounced() {
        XCTAssertEqual(QuestionQuota.default.wireKinds, ["basic", "cloze", "choice"])
        XCTAssertEqual(QuestionQuota(basic: 8, cloze: 0, choice: 0).wireKinds, ["basic"])
        XCTAssertEqual(QuestionQuota(basic: 4, cloze: 0, choice: 5).wireKinds, ["basic", "choice"])
        XCTAssertEqual(
            QuestionQuota(basic: 0, cloze: 5, choice: 5).wireCounts,
            ["basic": 0, "cloze": 5, "choice": 5]
        )
    }

    /// Un format à zéro est un choix légitime, et il est respecté à la lettre : c'est tout
    /// l'intérêt d'un nombre plutôt que d'un interrupteur.
    func testAFormatSetToZeroIsKept() {
        let quota = QuestionQuota(basic: 0, cloze: 6, choice: 6).clamped()

        XCTAssertEqual(quota.basic, 0)
        XCTAssertEqual(quota.total, 12)
        XCTAssertEqual(quota.kinds, [.cloze, .choice])
    }

    func testAnEmptyQuotaFallsBackOnBasicCards() {
        let quota = QuestionQuota(basic: 0, cloze: 0, choice: 0).clamped()

        XCTAssertEqual(quota.total, QuestionQuota.totalRange.lowerBound)
        XCTAssertEqual(quota.kinds, [.basic])
    }

    /// Le plafond rogne le format le plus nombreux : une petite commande passe entière.
    func testTheCapTrimsTheLargestFormatFirst() {
        let quota = QuestionQuota(basic: 20, cloze: 20, choice: 3).clamped()

        XCTAssertEqual(quota.total, QuestionQuota.totalRange.upperBound)
        XCTAssertEqual(quota.choice, 3)
    }

    // MARK: - Sens inverse

    func testReverseCardsAreCreatedOncePerCard() throws {
        let course = try makeCourse(title: "Espagnol", subject: "Espagnol")
        try CourseRepository.addFlashcards(
            [
                GeneratedFlashcard(front: "la maison", back: "la casa", hint: nil),
                GeneratedFlashcard(front: "le chien", back: "el perro", hint: nil)
            ],
            to: course,
            in: context
        )

        let created = try CourseRepository.addReverseCards(for: course, in: context)

        XCTAssertEqual(created.count, 2)
        XCTAssertEqual(created.map(\.front).sorted(), ["el perro", "la casa"])
        XCTAssertTrue(created.allSatisfy(\.isReversed))
        XCTAssertEqual(course.cards.count, 4)

        // Deuxième passage : rien de nouveau, on ne double pas les paires.
        let again = try CourseRepository.addReverseCards(for: course, in: context)
        XCTAssertTrue(again.isEmpty)
        XCTAssertEqual(course.cards.count, 4)
    }

    func testReversePairSharesAGroupButNotItsSchedule() throws {
        let course = try makeCourse(title: "Japonais", subject: "Japonais")
        try CourseRepository.addFlashcards(
            [GeneratedFlashcard(front: "l'eau", back: "みず", hint: nil)],
            to: course,
            in: context
        )

        let reverse = try CourseRepository.addReverseCards(for: course, in: context).first
        let original = course.cards.first { !$0.isReversed }

        XCTAssertNotNil(reverse)
        XCTAssertEqual(reverse?.groupID, original?.groupID)
        XCTAssertNotEqual(reverse?.id, original?.id)

        // Noter un sens ne touche pas l'autre.
        let outcome = SM2Scheduler.schedule(
            snapshot: SM2CardSnapshot(card: original!),
            rating: .good,
            now: Date(),
            config: .deterministic
        )
        original?.apply(outcome, at: Date())

        XCTAssertEqual(reverse?.state, .new)
        XCTAssertEqual(reverse?.intervalDays, 0)
    }

    func testLanguageCoursesAreRecognised() {
        XCTAssertTrue(SubjectHeuristics.isLanguage(subject: "Espagnol", title: "Unité 3"))
        XCTAssertTrue(SubjectHeuristics.isLanguage(subject: nil, title: "Vocabulaire japonais"))
        XCTAssertTrue(SubjectHeuristics.isLanguage(subject: "Anglais", title: "Irregular verbs"))
        XCTAssertFalse(SubjectHeuristics.isLanguage(subject: "SVT", title: "La photosynthèse"))
        XCTAssertFalse(SubjectHeuristics.isLanguage(subject: "Mathématiques", title: "Les fonctions affines"))
    }
}

/// Ce qui se passe quand l'import échoue : message utile, doublons repérés.
final class ImportFailureTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Course.self,
            Flashcard.self,
            ReviewLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    private func isEnableVision(_ recovery: ImportFailure.Recovery) -> Bool {
        if case .enableVision = recovery { return true }
        return false
    }

    private let longText = String(repeating: "La photosynthèse transforme la lumière en matière organique. ", count: 6)

    func testHandwrittenPhotoThatGivesNothingIsExplained() {
        let failure = ImportReadiness.failure(text: "  ", hasImages: false, canEnableVision: true, kind: .photo)

        XCTAssertNotNil(failure)
        XCTAssertEqual(failure?.title, "Ces pages sont illisibles")
        XCTAssertTrue(failure?.message.contains("Aucun texte") ?? false)
        XCTAssertTrue(isEnableVision(failure?.recovery ?? .none), "On doit proposer le modèle de vision")
    }

    func testScannedPdfSuggestsVisionOnlyWhenItIsStillAvailable() {
        let withOption = ImportReadiness.failure(text: "Chapitre 1", hasImages: false, canEnableVision: true, kind: .pdf)
        let withoutOption = ImportReadiness.failure(text: "Chapitre 1", hasImages: false, canEnableVision: false, kind: .pdf)

        XCTAssertTrue(isEnableVision(withOption?.recovery ?? .none))
        XCTAssertFalse(isEnableVision(withoutOption?.recovery ?? .none))
    }

    func testEnoughTextPassesThrough() {
        XCTAssertNil(ImportReadiness.failure(text: longText, hasImages: false, canEnableVision: true, kind: .pdf))
    }

    func testImagesSentToVisionAreEnoughOnTheirOwn() {
        XCTAssertNil(ImportReadiness.failure(text: "", hasImages: true, canEnableVision: false, kind: .pdf))
    }

    /// Un paquet de cartes n'emprunte pas l'écran d'import : le compilateur doit quand
    /// même connaître ce cas, et le garde ne doit rien inventer pour lui.
    func testCardsKindIsNotADocumentImport() {
        XCTAssertFalse(ImportKind.cards.producesSheet)
        XCTAssertEqual(ImportKind.cards.courseSource, .deck)
        XCTAssertFalse(CourseSource.deck.expectsSheet)
        XCTAssertNil(
            ImportReadiness.failure(
                text: "",
                hasImages: false,
                canEnableVision: false,
                kind: .cards
            )
        )
    }

    /// Chaque source a un libellé, une icône et une `CourseSource` : un cas oublié ici
    /// est le même oubli qui faisait échouer le `switch` de `ImportView`.
    func testEveryImportKindIsFullyDescribed() {
        for kind in ImportKind.allCases {
            XCTAssertFalse(kind.title.isEmpty, "\(kind.rawValue) sans titre")
            XCTAssertFalse(kind.systemImage.isEmpty, "\(kind.rawValue) sans icône")
            XCTAssertFalse(kind.courseSource.label.isEmpty, "\(kind.rawValue) sans source")
        }
        XCTAssertTrue(ImportKind.allCases.contains(.cards))
    }

    // MARK: - Doublons

    func testSameChapterImportedTwiceIsDetected() throws {
        let raw = longText
        _ = try CourseRepository.save(
            GeneratedCourse(title: "La photosynthèse", subject: "SVT", emoji: "🌿", summary: "", contextText: raw),
            source: .pdf,
            rawText: raw,
            in: context
        )

        let duplicate = CourseRepository.duplicate(title: "Chapitre 4", rawText: raw, in: context)

        XCTAssertEqual(duplicate?.title, "La photosynthèse", "Le même contenu doit être reconnu, même sous un autre nom")
    }

    func testSameTitleIsAlsoEnough() throws {
        _ = try CourseRepository.save(
            GeneratedCourse(title: "La photosynthèse", subject: "SVT", emoji: "🌿", summary: "", contextText: "court"),
            source: .pdf,
            rawText: "court",
            in: context
        )

        XCTAssertNotNil(CourseRepository.duplicate(title: "la  Photosynthese ", rawText: "autre chose", in: context))
    }

    func testADifferentChapterIsNotADuplicate() throws {
        _ = try CourseRepository.save(
            GeneratedCourse(title: "La photosynthèse", subject: "SVT", emoji: "🌿", summary: "", contextText: longText),
            source: .pdf,
            rawText: longText,
            in: context
        )

        let other = String(repeating: "Les fonctions affines s'écrivent f(x) = ax + b partout. ", count: 6)
        XCTAssertNil(CourseRepository.duplicate(title: "Les fonctions affines", rawText: other, in: context))
    }

    func testShortTextsDoNotFingerprintAndSoDoNotCollide() {
        XCTAssertEqual(CourseFingerprint.make(from: "trop court"), "")
        XCTAssertFalse(CourseFingerprint.make(from: longText).isEmpty)
    }
}
