import SwiftUI
import XCTest
@testable import Micabo

/// **Le scanner d'exercices** : le parseur des étapes (réponses propres, cassées, LaTeX), la
/// matière devinée, le cadre de recadrage, et la porte de Mika sur chaque appel.
final class SolverParserTests: XCTestCase {
    // MARK: - Une réponse propre

    func testACleanReplyGivesStepsAnswerAndSubject() throws {
        let raw = """
        [SUBJECT] math
        [STEP] Isoler le terme en x
        On retire 3 des deux côtés.
        $$2x = 8$$
        [STEP] Diviser par 2
        On divise les deux membres par 2.
        [STEP] Vérifier
        $2 \\times 4 + 3 = 11$, c'est bon.
        [ANSWER] $x = 4$
        """
        let solution = try XCTUnwrap(SolverParser.parse(raw))
        XCTAssertEqual(solution.subject, .math)
        XCTAssertTrue(solution.isStructured)
        XCTAssertEqual(solution.steps.count, 3)
        XCTAssertEqual(solution.steps[0].title, "Isoler le terme en x")
        XCTAssertEqual(solution.steps[0].body, "On retire 3 des deux côtés.\n$$2x = 8$$")
        XCTAssertEqual(solution.steps[1].title, "Diviser par 2")
        XCTAssertEqual(solution.answer, "$x = 4$")
        XCTAssertTrue(solution.transcript(answerLabel: "Réponse").contains("Réponse : $x = 4$"))
    }

    // MARK: - Des réponses cassées

    /// Une phrase d'introduction, des balises en gras, numérotées, en français, avec deux
    /// points : tout se lit.
    func testSloppyTagsAreStillRead() throws {
        let raw = """
        Voici la solution !
        **[Step 1]** Calculer la masse molaire
        M = 12 + 2 × 16 = 44 g/mol.
        [ÉTAPE 2] : Calculer n : on divise la masse par M.
        [answer]: n = 0,5 mol
        """
        let solution = try XCTUnwrap(SolverParser.parse(raw))
        XCTAssertNil(solution.subject)
        XCTAssertEqual(solution.steps.count, 2)
        XCTAssertEqual(solution.steps[0].title, "Calculer la masse molaire")
        XCTAssertEqual(solution.steps[1].title, "Calculer n")
        XCTAssertEqual(solution.steps[1].body, "on divise la masse par M.")
        XCTAssertEqual(solution.answer, "n = 0,5 mol")
    }

    /// Sans balises : des lignes numérotées font des étapes.
    func testNumberedLinesWithoutTagsBecomeSteps() throws {
        let raw = """
        1. On développe le carré.
        2) On regroupe les termes.
        3. On conclut.
        """
        let solution = try XCTUnwrap(SolverParser.parse(raw))
        XCTAssertFalse(solution.isStructured)
        XCTAssertEqual(solution.steps.map(\.body), ["On développe le carré.", "On regroupe les termes.", "On conclut."])
    }

    /// Sans balises ni numéros : les paragraphes ; un seul paragraphe n'est pas une solution
    /// pas à pas, l'écran affiche le texte tel quel.
    func testParagraphsOrPlainText() throws {
        let two = SolverParser.parse("Premier temps du raisonnement.\n\nSecond temps du raisonnement.")
        XCTAssertEqual(two?.steps.count, 2)
        XCTAssertNil(SolverParser.parse("Une seule phrase, sans structure."))
        XCTAssertNil(SolverParser.parse(""))
        XCTAssertEqual(SolverParser.untagged("[ANSWER] 12"), "12")
    }

    /// Une réponse sans étapes balisées mais avec `[ANSWER]` garde la réponse et les
    /// paragraphes d'avant.
    func testAnswerWithoutSteps() throws {
        let solution = try XCTUnwrap(SolverParser.parse("On factorise.\n\nOn applique la règle du produit nul.\n[ANSWER] x = 1 ou x = 3"))
        XCTAssertEqual(solution.answer, "x = 1 ou x = 3")
        XCTAssertEqual(solution.steps.count, 2)
    }

    /// Des balises inconnues (`[x]`, un lien) ne coupent rien.
    func testUnknownBracketsAreText() throws {
        let solution = try XCTUnwrap(SolverParser.parse("[STEP] Lire l'intervalle\nSur [a, b] et [x], f est continue.\n[STEP] Conclure\nDonc oui."))
        XCTAssertEqual(solution.steps.count, 2)
        XCTAssertEqual(solution.steps[0].body, "Sur [a, b] et [x], f est continue.")
    }

    // MARK: - Le LaTeX

    /// `\frac` écrit sans doubler l'antislash dans le JSON arrive comme un saut de page suivi
    /// de « rac » ; `\times` comme une tabulation. Le parseur remet l'antislash.
    func testLostEscapesAreRepaired() {
        XCTAssertEqual(SolverParser.repaired("$\u{0C}rac{1}{2}$"), "$\\frac{1}{2}$")
        XCTAssertEqual(SolverParser.repaired("$3 \ttimes 4$"), "$3 \\times 4$")
        XCTAssertEqual(SolverParser.repaired("$\u{08}eta$"), "$\\beta$")
        XCTAssertEqual(SolverParser.repaired("$x \nneq 2$"), "$x \\neq 2$")
        XCTAssertEqual(SolverParser.repaired("\\(x^2\\) et \\[y = 3\\]"), "$x^2$ et $$y = 3$$")
    }

    func testFormulaLinesAreSetApart() {
        let blocks = SolverParser.blocks(of: "On remplace :\n$$\\frac{a}{b} = 2$$\nDonc $a = 2b$ ici.")
        XCTAssertEqual(blocks, [
            .text("On remplace :"),
            .formula("\\frac{a}{b} = 2"),
            .text("Donc $a = 2b$ ici."),
        ])
    }

    func testAFormulaOverSeveralLinesIsOneBlock() {
        let blocks = SolverParser.blocks(of: "$$\nx = \\frac{-b}{2a}\n$$\nVoilà.")
        XCTAssertEqual(blocks, [.formula("x = \\frac{-b}{2a}"), .text("Voilà.")])
    }

    func testAnUnclosedFormulaStaysText() {
        let blocks = SolverParser.blocks(of: "$$x = 2")
        XCTAssertEqual(blocks, [.text("$$x = 2")])
        XCTAssertEqual(SolverParser.blocks(of: "$x = 4$"), [.formula("x = 4")])
    }

    // MARK: - L'entraînement

    func testPracticeAndVerdict() throws {
        let practice = try XCTUnwrap(SolverParser.practice("[EXERCISE] Résoudre 3x - 5 = 10.\n[ANSWER] x = 5"))
        XCTAssertEqual(practice.exercise, "Résoudre 3x - 5 = 10.")
        XCTAssertEqual(practice.expected, "x = 5")
        XCTAssertEqual(SolverParser.practice("Résoudre 3x - 5 = 10.")?.expected, nil)

        let right = SolverParser.verdict("[RIGHT] Bravo, c'est exactement ça.")
        XCTAssertEqual(right.verdict, .right)
        XCTAssertEqual(right.text, "Bravo, c'est exactement ça.")
        XCTAssertEqual(SolverParser.verdict("**[WRONG]** Tu as oublié le signe.").verdict, .wrong)
        XCTAssertNil(SolverParser.verdict("Je ne sais pas.").verdict)
    }

    // MARK: - La matière

    func testTheSubjectIsGuessedFromTheStatement() {
        XCTAssertEqual(SolverSubjectGuess.guess("Résoudre l'équation 2x² − 8x + 6 = 0"), .math)
        XCTAssertEqual(SolverSubjectGuess.guess("Calculer la vitesse d'une voiture qui parcourt 120 km en 2 h."), .physics)
        XCTAssertEqual(SolverSubjectGuess.guess("Quelle est la masse molaire du CO2 ? (g/mol)"), .physics)
        XCTAssertEqual(SolverSubjectGuess.guess("Décris le rôle de l'ADN dans la cellule."), .biology)
        XCTAssertEqual(SolverSubjectGuess.guess("Löse die Gleichung 3x + 2 = 11."), .math)
        // Lot 7 : une question de langue ou d'histoire a sa famille.
        XCTAssertEqual(SolverSubjectGuess.guess("Analyse le poème de Victor Hugo."), .languages)
        XCTAssertEqual(SolverSubjectGuess.guess("Conjugue le verbe aller au subjonctif présent."), .languages)
        XCTAssertEqual(SolverSubjectGuess.guess("Quelles sont les causes de la Première Guerre mondiale ?"), .humanities)
        XCTAssertEqual(SolverSubjectGuess.guess("Nenne die Ursachen des Ersten Weltkriegs."), .humanities)
        XCTAssertEqual(SolverSubjectGuess.guess("Comment bien dormir ?"), .other)
        XCTAssertEqual(SolverSubject(modelWord: "languages"), .languages)
        XCTAssertEqual(SolverSubject(modelWord: "humanities"), .humanities)
        XCTAssertEqual(SolverSubject(stored: "humanities"), .humanities)
        XCTAssertEqual(SolverSubject(stored: "inconnue"), .other)
        XCTAssertEqual(SolverSubjectGuess.guess("12 + 7 = ?  et 3 × 4 = ?"), .math)
        XCTAssertEqual(SolverSubject(modelWord: "physics"), .physics)
        XCTAssertEqual(SolverSubject(modelWord: " biology"), .biology)
        XCTAssertNil(SolverSubject(modelWord: "???"))
    }

    // MARK: - Le cadre

    func testTheFrameMapsToThePhotoWhenItFits() throws {
        // Une photo 1000 × 2000 dans un écran 400 × 400 : posée en 200 × 400, centrée.
        let shown = SolverCrop.displayedRect(image: CGSize(width: 1000, height: 2000), in: CGSize(width: 400, height: 400), fit: .fit)
        XCTAssertEqual(shown, CGRect(x: 100, y: 0, width: 200, height: 400))
        let rect = try XCTUnwrap(SolverCrop.imageRect(
            for: CGRect(x: 100, y: 100, width: 100, height: 100),
            image: CGSize(width: 1000, height: 2000),
            in: CGSize(width: 400, height: 400),
            fit: .fit
        ))
        XCTAssertEqual(rect, CGRect(x: 0, y: 500, width: 500, height: 500))
    }

    func testTheFrameMapsToThePhotoWhenItFills() throws {
        // Une photo 3000 × 4000 dans un écran 390 × 844 : remplie, elle déborde sur les côtés.
        let image = CGSize(width: 3000, height: 4000)
        let screen = CGSize(width: 390, height: 844)
        let shown = SolverCrop.displayedRect(image: image, in: screen, fit: .fill)
        XCTAssertEqual(shown.height, 844, accuracy: 0.01)
        XCTAssertLessThan(shown.minX, 0)
        let rect = try XCTUnwrap(SolverCrop.imageRect(for: CGRect(x: 0, y: 0, width: 390, height: 844), image: image, in: screen, fit: .fill))
        XCTAssertEqual(rect.height, 4000, accuracy: 1)
        XCTAssertLessThan(rect.width, 3000)
        XCTAssertEqual(rect.midX, 1500, accuracy: 1)
        // Hors de la photo : rien.
        XCTAssertNil(SolverCrop.imageRect(for: CGRect(x: -500, y: 0, width: 10, height: 10), image: image, in: screen, fit: .fit))
    }

    func testTheFrameStaysOnScreen() {
        let screen = CGSize(width: 390, height: 844)
        let clamped = SolverCrop.clamped(CGRect(x: 350, y: -40, width: 20, height: 900), in: screen, minimum: 80)
        XCTAssertEqual(clamped.width, 80)
        XCTAssertEqual(clamped.maxX, 390)
        XCTAssertEqual(clamped.minY, 0)
        XCTAssertEqual(clamped.height, 844)
        let initial = SolverCrop.initialFrame(in: screen)
        XCTAssertGreaterThan(initial.width, initial.height)
        XCTAssertTrue(CGRect(origin: .zero, size: screen).contains(initial))
    }
}

// MARK: - La porte et l'XP

final class SolverSessionTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "micabo.tests.solver.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private let reply = """
    [SUBJECT] physics
    [STEP] Écrire la formule
    $$v = \\frac{d}{t}$$
    [STEP] Remplacer
    $v = 120 / 2$
    [ANSWER] $v = 60$ km/h
    """

    /// **La première solution est la question offerte** : elle rapporte `exerciseSolved`,
    /// prend la matière que Mika a lue, et dévoile la première étape. La suite (« Je ne
    /// comprends pas cette étape ») passe par le paywall `mika`.
    @MainActor
    func testTheFreeQuestionSolvesThenTheNextAskOpensThePaywall() async {
        let quota = MikaQuota(defaults: freshDefaults())
        let xp = XPStore(defaults: freshDefaults())
        let exercise = SolvedExercise(statement: "Une voiture parcourt 120 km en 2 h. Quelle est sa vitesse ?", subject: .other, source: .typed, thumbnail: nil)
        let session = SolverSession(exercise: exercise, quota: quota, xp: xp)
        XCTAssertEqual(session.phase, .review)

        await session.solve(isPro: false, service: SolverStubAI(text: reply), context: nil)
        XCTAssertEqual(session.phase, .solved)
        XCTAssertEqual(session.steps.count, 2)
        XCTAssertEqual(session.revealed, 1)
        XCTAssertTrue(session.hasMoreSteps)
        XCTAssertEqual(exercise.subject, .physics)
        XCTAssertEqual(xp.today, XPRules.exerciseSolved)
        XCTAssertFalse(quota.hasFreeQuestion)

        session.revealNext()
        XCTAssertFalse(session.hasMoreSteps)
        XCTAssertTrue(session.showsAnswer)

        await session.explain(step: 0, isPro: false, service: SolverStubAI(text: "Autrement dit."))
        XCTAssertEqual(session.paywall, .mika)
        XCTAssertTrue(session.help.isEmpty)
        XCTAssertEqual(xp.today, XPRules.exerciseSolved)
    }

    /// **Sans question offerte**, l'énoncé reste lu et la solution attend Pro : rien n'est
    /// envoyé, rien n'est gagné.
    @MainActor
    func testWithoutTheFreeQuestionTheSolutionIsLocked() async {
        let quota = MikaQuota(defaults: freshDefaults())
        quota.noteAnswered()
        let xp = XPStore(defaults: freshDefaults())
        let session = SolverSession(
            exercise: SolvedExercise(statement: "Résoudre 2x + 3 = 11", subject: .math, source: .camera, thumbnail: nil),
            quota: quota,
            xp: xp
        )
        await session.solve(isPro: false, service: SolverStubAI(text: reply), context: nil)
        XCTAssertEqual(session.phase, .locked)
        XCTAssertEqual(session.paywall, .mika)
        XCTAssertNil(session.exercise.solutionRaw)
        XCTAssertEqual(xp.today, 0)
    }

    /// Un abonné : l'explication d'une étape, l'exercice similaire et sa correction rapportent
    /// chacun `mikaAnswer`. La matière choisie par l'élève n'est pas écrasée par Mika.
    @MainActor
    func testAProUserGetsHelpPracticeAndCorrection() async {
        let xp = XPStore(defaults: freshDefaults())
        let session = SolverSession(
            exercise: SolvedExercise(statement: "Une voiture parcourt 120 km en 2 h.", subject: .other, source: .camera, thumbnail: nil),
            quota: MikaQuota(defaults: freshDefaults()),
            xp: xp
        )
        session.setSubject(.math)
        await session.solve(isPro: true, service: SolverStubAI(text: reply), context: nil)
        XCTAssertEqual(session.exercise.subject, .math)

        await session.explain(step: 1, isPro: true, service: SolverStubAI(text: "On divise la distance par le temps."))
        XCTAssertEqual(session.help[1], "On divise la distance par le temps.")

        await session.startPractice(isPro: true, service: SolverStubAI(text: "[EXERCISE] Un train parcourt 300 km en 3 h.\n[ANSWER] 100 km/h"))
        XCTAssertEqual(session.practice?.expected, "100 km/h")

        await session.check(answer: "100 km/h", isPro: true, service: SolverStubAI(text: "[RIGHT] Exact."))
        XCTAssertEqual(session.practice?.verdict, .right)
        XCTAssertEqual(session.practice?.attempt, "100 km/h")
        XCTAssertEqual(xp.today, XPRules.exerciseSolved + 3 * XPRules.mikaAnswer)
    }

    /// Une réponse sans balises s'affiche telle quelle, et une panne laisse réessayer sans
    /// brûler la question offerte.
    @MainActor
    func testPlainRepliesAndFailures() async {
        let quota = MikaQuota(defaults: freshDefaults())
        let session = SolverSession(
            exercise: SolvedExercise(statement: "Analyse ce poème.", subject: .other, source: .typed, thumbnail: nil),
            quota: quota,
            xp: XPStore(defaults: freshDefaults())
        )
        await session.solve(isPro: false, service: SolverStubAI(text: nil), context: nil)
        if case .failed = session.phase {} else { XCTFail("une panne doit se voir") }
        XCTAssertTrue(quota.hasFreeQuestion)

        await session.solve(isPro: false, service: SolverStubAI(text: "Un seul paragraphe d'analyse."), context: nil)
        XCTAssertEqual(session.phase, .solved)
        XCTAssertNil(session.solution)
        XCTAssertEqual(session.plainReply, "Un seul paragraphe d'analyse.")
    }

    /// Le fil d'une matière : un exercice arrivé y part avec son titre, et le dernier tour est
    /// celui de l'élève.
    @MainActor
    func testTheTutorRequestCarriesTheThread() {
        let messages = [
            TutorMessage(subject: .math, role: .user, text: "Résoudre 2x = 8", exerciseID: UUID()),
            TutorMessage(subject: .math, role: .mika, text: "$x = 4$", exerciseID: UUID()),
            TutorMessage(subject: .math, role: .user, text: "Pourquoi on divise ?"),
        ]
        let request = TutorChat.request(for: messages, subject: .math, context: nil)
        XCTAssertEqual(request.turns.count, 3)
        XCTAssertTrue(request.turns[0].text.hasSuffix("Résoudre 2x = 8"))
        XCTAssertNotEqual(request.turns[0].text, "Résoudre 2x = 8")
        XCTAssertEqual(request.turns.last?.role, .user)
        XCTAssertEqual(request.attachment?.title, SolverSubject.math.label)
    }

    /// Les phrases du scanner existent dans toutes les langues, y compris celles qu'on
    /// compose (`solveText`) et que le test général ne lit pas dans le code.
    func testEverySolverKeyExistsInEveryLanguage() {
        let french = IosI18nCatalogs.fr.keys.filter { $0.hasPrefix("ios.solve.") }
        XCTAssertGreaterThan(french.count, 80)
        var dynamic = ["capture.hint", "capture.adjust", "capture.reading", "capture.flashOn", "capture.flashOff", "practice.right", "practice.wrong"]
        for key in dynamic {
            XCTAssertNotNil(IosI18nCatalogs.fr["ios.solve.\(key)"], key)
        }
        // Le nom de chaque matière et ses deux idées de question, dans toutes les langues : les
        // familles du lot 7 portent leurs propres clés (`ios.ku7.*`).
        let subjectKeys = SolverSubject.allCases.flatMap { [$0.labelKey, $0.suggestionKey(1), $0.suggestionKey(2)] }
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for key in subjectKeys {
                XCTAssertNotNil(table[key], "\(locale.rawValue) \(key)")
            }
            // La consigne de toutes les matières garde les balises que le parseur lit, et les
            // deux nouvelles familles.
            let solve = table["ios.ku7.prompt.solve"] ?? ""
            for tag in ["[SUBJECT]", "[STEP]", "[ANSWER]", "languages", "humanities"] {
                XCTAssertTrue(solve.contains(tag), "\(locale.rawValue) \(tag)")
            }
            XCTAssertTrue((table["ios.ku7.prompt.practice"] ?? "").contains("[EXERCISE]"), locale.rawValue)
        }
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for key in french {
                XCTAssertNotNil(table[key], "\(locale.rawValue) \(key)")
            }
            // Les balises restent en anglais : c'est ce que le parseur lit.
            let prompt = table["ios.solve.prompt.solve"] ?? ""
            for tag in ["[SUBJECT]", "[STEP]", "[ANSWER]"] {
                XCTAssertTrue(prompt.contains(tag), "\(locale.rawValue) \(tag)")
            }
            XCTAssertTrue((table["ios.solve.prompt.practice"] ?? "").contains("[EXERCISE]"), locale.rawValue)
            XCTAssertTrue((table["ios.solve.prompt.check"] ?? "").contains("[WRONG]"), locale.rawValue)
        }
    }

    /// Chaque `solveText("…")` écrit dans le code a sa phrase.
    func testEverySolveTextCallHasItsKey() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folders = ["Micabo/Features/Solver", "Micabo/Features/Mika"].map { root.appendingPathComponent($0) }
        let pattern = try NSRegularExpression(pattern: #"solveText\("([A-Za-z0-9.]+)""#)
        var keys: Set<String> = []
        for folder in folders {
            guard let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in files where url.pathExtension == "swift" {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    if let range = Range(match.range(at: 1), in: text) { keys.insert(String(text[range])) }
                }
            }
        }
        guard !keys.isEmpty else { throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur") }
        let missing = keys.filter { IosI18nCatalogs.fr["ios.solve.\($0)"] == nil }.sorted()
        XCTAssertEqual(missing, [])
    }
}

/// Une doublure de Mika : une réponse fixe, ou une panne.
private struct SolverStubAI: AIService {
    let text: String?

    func generateCourse(_ request: CourseGenerationRequest) async throws -> GeneratedCourse {
        throw AIServiceError.notConfigured
    }

    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard] {
        throw AIServiceError.notConfigured
    }

    func explain(_ request: SelectionExplanationRequest) async throws -> SelectionExplanation {
        throw AIServiceError.notConfigured
    }

    func chat(_ request: MikaChatRequest) async throws -> MikaChatReply {
        guard let text else { throw AIServiceError.network("hors ligne") }
        return MikaChatReply(reply: text, card: nil)
    }
}
