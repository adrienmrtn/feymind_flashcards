import UIKit
import XCTest
@testable import Micabo

/// **Le lot 7 « tout Knowunity »** : l'aide aux devoirs dans toutes les matières, « Corriger un
/// texte », la recherche dans le contenu des leçons. Tout passe par `mika-chat` ou se fait sur
/// l'appareil : aucune fonction serveur nouvelle.
final class KnowunityGapTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "micabo.tests.ku7.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - La relecture

    private let structured = """
    **[SUMMARY]** Ton récit est clair et bien construit, mais attention aux accords du participe passé.
    [FIX] « je suis aller »
    => je suis allé
    Avec être, le participe passé s'accorde et se termine en -é, pas en -er.
    [FIX 2] cinema → cinéma
    Il faut un accent aigu sur le e.
    [CORRECTION] Il pleuvait
    => Il pleuvait
    Rien à changer : ce n'est pas une correction.
    [TIP] Relis chaque verbe après « être » et « avoir ».
    """

    func testTheReviewReadsSummaryFixesAndTip() {
        let review = WritingParser.parse(structured)
        XCTAssertTrue(review.isStructured)
        XCTAssertEqual(review.summary, "Ton récit est clair et bien construit, mais attention aux accords du participe passé.")
        XCTAssertEqual(review.fixes.count, 2, "une correction qui ne change rien n'en est pas une")
        XCTAssertEqual(review.fixes[0].original, "je suis aller")
        XCTAssertEqual(review.fixes[0].corrected, "je suis allé")
        XCTAssertTrue(review.fixes[0].why.hasPrefix("Avec être"))
        XCTAssertEqual(review.fixes[1].original, "cinema")
        XCTAssertEqual(review.fixes[1].corrected, "cinéma")
        XCTAssertEqual(review.fixes.map(\.id), [0, 1])
        XCTAssertEqual(review.tip, "Relis chaque verbe après « être » et « avoir ».")
    }

    func testAReplyWithoutTagsIsShownAsIs() {
        let review = WritingParser.parse("Ton texte est très bien, je ne vois rien à corriger.")
        XCTAssertFalse(review.isStructured)
        XCTAssertEqual(review.plain, "Ton texte est très bien, je ne vois rien à corriger.")
        XCTAssertTrue(review.fixes.isEmpty)
    }

    /// **Les corrections s'appliquent sur l'appareil**, à leur première place libre ; un
    /// passage que le modèle a réécrit (introuvable) ne touche pas au texte.
    func testFixesAreAppliedToTheStudentText() {
        let text = "Hier, je suis aller au cinema avec mes amis. Le cinema était plein."
        let fixes = [
            WritingFix(id: 0, original: "je suis aller", corrected: "je suis allé", why: ""),
            WritingFix(id: 1, original: "cinema", corrected: "cinéma", why: ""),
            WritingFix(id: 2, original: "un passage réécrit", corrected: "autre chose", why: ""),
        ]
        let segments = WritingParser.segments(of: text, fixes: fixes)
        XCTAssertEqual(segments.filter(\.isFixed).count, 2)
        XCTAssertEqual(
            WritingParser.corrected(text, fixes: fixes),
            "Hier, je suis allé au cinéma avec mes amis. Le cinema était plein."
        )
        XCTAssertEqual(WritingParser.corrected(text, fixes: []), text)
    }

    func testWordsAndBuckets() {
        XCTAssertEqual(WritingCount.words(in: "  Un texte\n\nde cinq   mots. "), 5)
        XCTAssertEqual(WritingCount.bucket(12), "lt50")
        XCTAssertEqual(WritingCount.bucket(220), "150-400")
    }

    // MARK: - La porte de Mika

    /// **La question offerte relit un texte**, puis le paywall `mika` : la même porte que le
    /// chat et le scanner. Le texte part en document joint, la consigne avec ses balises.
    @MainActor
    func testTheFreeQuestionReviewsThenTheNextOpensThePaywall() async {
        let quota = MikaQuota(defaults: freshDefaults())
        let xp = XPStore(defaults: freshDefaults())
        let service = RecordingAI(text: structured)
        let session = WritingSession(text: "Hier, je suis aller au cinema avec mes amis.", quota: quota, xp: xp)
        XCTAssertTrue(session.canCheck)

        await session.check(isPro: false, service: service)
        XCTAssertEqual(session.phase, .reviewed)
        XCTAssertEqual(session.correctedText, "Hier, je suis allé au cinéma avec mes amis.")
        XCTAssertFalse(quota.hasFreeQuestion)
        XCTAssertEqual(xp.today, XPRules.mikaAnswer)
        XCTAssertEqual(service.requests.count, 1)
        XCTAssertEqual(service.requests.first?.attachment?.text, "Hier, je suis aller au cinema avec mes amis.")
        let instruction = service.requests.first?.turns.last?.text ?? ""
        for tag in ["[SUMMARY]", "[FIX]", "[TIP]"] {
            XCTAssertTrue(instruction.contains(tag), tag)
        }

        session.restart()
        session.text = "Un deuxième texte à relire, avec des fautes."
        await session.check(isPro: false, service: service)
        XCTAssertEqual(session.phase, .locked)
        XCTAssertEqual(session.paywall, .mika)
        XCTAssertEqual(service.requests.count, 1, "rien n'est envoyé derrière la porte")
    }

    /// Une panne ne brûle pas la question offerte ; un texte trop court ne part pas.
    @MainActor
    func testFailuresAndShortTextsKeepTheFreeQuestion() async {
        let quota = MikaQuota(defaults: freshDefaults())
        let session = WritingSession(text: "Deux mots", quota: quota, xp: nil)
        XCTAssertFalse(session.canCheck)
        await session.check(isPro: false, service: RecordingAI(text: structured))
        XCTAssertEqual(session.phase, .editing)

        session.text = "Un texte assez long pour partir."
        await session.check(isPro: false, service: RecordingAI(text: nil))
        if case .failed = session.phase {} else { XCTFail("une panne doit se voir") }
        XCTAssertTrue(quota.hasFreeQuestion)
        XCTAssertTrue(session.canCheck, "on peut réessayer")
    }

    /// Un abonné au plafond du jour : un message, pas de paywall, rien d'envoyé.
    @MainActor
    func testAProUserAtTheDailyCapGetsANotice() async {
        let quota = MikaQuota(defaults: freshDefaults())
        for _ in 0..<MikaAllowance.proMessagesPerDay { quota.noteAnswered() }
        let service = RecordingAI(text: structured)
        let session = WritingSession(text: "Un texte assez long pour partir.", quota: quota, xp: nil)
        await session.check(isPro: true, service: service)
        XCTAssertNotNil(session.notice)
        XCTAssertNil(session.paywall)
        XCTAssertTrue(service.requests.isEmpty)
    }

    /// Une photo lue sur l'appareil : le texte arrive, ou un message quand rien n'est lisible.
    @MainActor
    func testAPhotoFillsTheTextOrSaysItIsUnreadable() async {
        let session = WritingSession(quota: MikaQuota(defaults: freshDefaults()), xp: nil)
        let image = UIImage()
        await session.read([image], recognize: { _ in "  ?? " })
        XCTAssertNotNil(session.readFailure)
        XCTAssertTrue(session.text.isEmpty)

        await session.read([image], recognize: { _ in "Dear Sir, I am writting to you about the job." })
        XCTAssertNil(session.readFailure)
        XCTAssertEqual(session.text, "Dear Sir, I am writting to you about the job.")
        XCTAssertEqual(session.source, .photo)
    }

    // MARK: - L'aide aux devoirs, toutes matières

    /// La consigne de résolution tient dans un message de `mika-chat` (1 500 caractères côté
    /// serveur), niveau compris, dans toutes les langues ; idem pour la relecture.
    func testPromptsFitInOneMikaMessageInEveryLanguage() {
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            let level = (table["ios.ku7.prompt.level"] ?? "").replacingOccurrences(of: "{level}", with: "Gymnasium (Oberstufe)")
            for key in ["ios.ku7.prompt.solve", "ios.ku7.prompt.practice", "ios.ku7.writing.prompt"] {
                let prompt = (table[key] ?? "") + "\n" + level
                XCTAssertLessThan(prompt.count, MikaLimits.messageCharacters, "\(locale.rawValue) \(key)")
            }
            let writing = table["ios.ku7.writing.prompt"] ?? ""
            for tag in ["[SUMMARY]", "[FIX]", "[TIP]", "=>"] {
                XCTAssertTrue(writing.contains(tag), "\(locale.rawValue) \(tag)")
            }
        }
    }

    func testTheLevelIsAddedWhenKnown() {
        let prompt = "Consigne."
        XCTAssertEqual(HomeworkLevel.appending(nil, to: prompt), prompt)
        XCTAssertEqual(HomeworkLevel.appending("  ", to: prompt), prompt)
        let withLevel = HomeworkLevel.appending("Gymnasium", to: prompt)
        XCTAssertTrue(withLevel.hasPrefix("Consigne.\n"))
        XCTAssertTrue(withLevel.contains("Gymnasium"))
        XCTAssertTrue(SolverPrompts.solve(level: nil).contains("humanities"))
        XCTAssertTrue(SolverPrompts.practice(level: nil).contains("[EXERCISE]"))
    }

    // MARK: - La recherche

    func testSearchReadsTheContentWithoutAccentsOrCase() {
        let entry = LessonSearch.entry(
            title: "Évolution",
            subject: "SVT",
            summary: "",
            chapters: ["La sélection naturelle"],
            cards: [(front: "Qui a écrit L'Origine des espèces ?", back: "Charles Darwin, en 1859", hint: nil)],
            source: "La guerre froide n'a rien à voir, mais le mot est là."
        )
        XCTAssertTrue(LessonSearch.matches(entry, query: "evolution"))
        XCTAssertTrue(LessonSearch.matches(entry, query: "DARWIN"))
        XCTAssertTrue(LessonSearch.matches(entry, query: "selection"))
        XCTAssertTrue(LessonSearch.matches(entry, query: "froide guerre"))
        XCTAssertFalse(LessonSearch.matches(entry, query: "darwin mendel"))
        XCTAssertTrue(LessonSearch.matches(entry, query: "   "))
        XCTAssertFalse(LessonSearch.matches(nil, query: "darwin"))
    }

    // MARK: - Les outils de Home et les statistiques

    func testHomeToolsAndEventsCarryNoStudentText() {
        XCTAssertEqual(HomeTool.allCases.map(\.analyticsName), ["scan", "writing", "quiz"])
        for event in [AnalyticsEvent.homeToolOpened, .writingOpened, .writingUnreadable, .writingChecked, .writingCopied] {
            XCTAssertTrue(event.rawValue.allSatisfy { $0.isLowercase || $0 == "_" }, event.rawValue)
        }
    }
}

/// Un service qui garde chaque demande et rend un texte fixe (ou une panne sans texte).
private final class RecordingAI: AIService {
    let text: String?
    private(set) var requests: [MikaChatRequest] = []

    init(text: String?) {
        self.text = text
    }

    func generateCourse(_ request: CourseGenerationRequest) async throws -> GeneratedCourse { throw AIServiceError.notConfigured }
    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard] { throw AIServiceError.notConfigured }
    func explain(_ request: SelectionExplanationRequest) async throws -> SelectionExplanation { throw AIServiceError.notConfigured }

    func chat(_ request: MikaChatRequest) async throws -> MikaChatReply {
        requests.append(request)
        guard let text else { throw AIServiceError.network("hors ligne") }
        return MikaChatReply(reply: text, card: nil)
    }
}
