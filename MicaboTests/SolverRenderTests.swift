import SwiftUI
import XCTest
@testable import Micabo

/// **Les rendus du scanner d'exercices et de « Demande à Mika »**, de jour, de nuit, en
/// allemand et en arabe. Sans caméra ni défilement : la capture est posée sur sa scène de
/// démonstration, la solution est dessinée en pile.
@MainActor
final class SolverRenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
    }

    private func freshDefaults() -> UserDefaults {
        let name = "micabo.tests.solver.render.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - Les contenus

    private struct Sample {
        var statement: String
        var reply: String
        var help: String
        var practice: SolverPractice
    }

    private let french = Sample(
        statement: "Exercice 3. Résoudre dans ℝ l'équation $2x^2 - 8x + 6 = 0$.",
        reply: """
        [SUBJECT] math
        [STEP] Simplifier l'équation
        Tous les coefficients sont pairs : on divise les deux membres par 2.
        $$x^2 - 4x + 3 = 0$$
        [STEP] Calculer le discriminant
        Pour $ax^2 + bx + c = 0$, on calcule $\\Delta = b^2 - 4ac$ avec $a = 1$, $b = -4$, $c = 3$.
        $$\\Delta = (-4)^2 - 4 \\times 1 \\times 3 = 4$$
        [STEP] Trouver les deux racines
        **$\\Delta > 0$** : l'équation a deux solutions.
        $$x = \\frac{-b \\pm \\sqrt{\\Delta}}{2a} = \\frac{4 \\pm 2}{2}$$
        [ANSWER] $x = 1$ ou $x = 3$
        """,
        help: "Le discriminant dit combien de solutions il y a. Ici, on remplace juste les lettres par les nombres de l'équation : $b = -4$ donc $b^2 = 16$, et $4ac = 12$. Il reste $16 - 12 = 4$.",
        practice: SolverPractice(
            exercise: "Résoudre dans ℝ l'équation $3x^2 - 12x + 9 = 0$.",
            expected: "$x = 1$ ou $x = 3$",
            attempt: "x = 3",
            verdict: .wrong,
            feedback: "Tu as trouvé une des deux racines, bravo. Mais $\\Delta > 0$ : il en manque une ! Avec $\\Delta = 36$, la seconde est $x = \\frac{12 - 6}{6} = 1$."
        )
    )

    private let german = Sample(
        statement: "Aufgabe 3. Löse die Gleichung $2x^2 - 8x + 6 = 0$.",
        reply: """
        [SUBJECT] math
        [STEP] Die Gleichung vereinfachen
        Alle Koeffizienten sind gerade: Wir teilen beide Seiten durch 2.
        $$x^2 - 4x + 3 = 0$$
        [STEP] Die Diskriminante berechnen
        Für $ax^2 + bx + c = 0$ gilt $D = b^2 - 4ac$ mit $a = 1$, $b = -4$, $c = 3$.
        $$D = (-4)^2 - 4 \\times 1 \\times 3 = 4$$
        [STEP] Die beiden Lösungen finden
        **$D > 0$**: Die Gleichung hat zwei Lösungen.
        $$x = \\frac{-b \\pm \\sqrt{D}}{2a} = \\frac{4 \\pm 2}{2}$$
        [ANSWER] $x = 1$ oder $x = 3$
        """,
        help: "Die Diskriminante sagt dir, wie viele Lösungen es gibt. Du setzt einfach die Zahlen ein: $b = -4$, also $b^2 = 16$, und $4ac = 12$. Bleibt $16 - 12 = 4$.",
        practice: SolverPractice(exercise: "Löse $3x^2 - 12x + 9 = 0$.", expected: "$x = 1$ oder $x = 3$")
    )

    private let arabic = Sample(
        statement: "التمرين 3. حلّ المعادلة $2x^2 - 8x + 6 = 0$.",
        reply: """
        [SUBJECT] math
        [STEP] تبسيط المعادلة
        كل المعاملات زوجية: نقسم الطرفين على 2.
        $$x^2 - 4x + 3 = 0$$
        [STEP] حساب المميّز
        للمعادلة $ax^2 + bx + c = 0$ نحسب $\\Delta = b^2 - 4ac$ حيث $a = 1$ و $b = -4$ و $c = 3$.
        $$\\Delta = (-4)^2 - 4 \\times 1 \\times 3 = 4$$
        [STEP] إيجاد الحلّين
        **$\\Delta > 0$**: للمعادلة حلّان.
        $$x = \\frac{-b \\pm \\sqrt{\\Delta}}{2a} = \\frac{4 \\pm 2}{2}$$
        [ANSWER] $x = 1$ أو $x = 3$
        """,
        help: "المميّز يخبرك بعدد الحلول. نعوّض فقط بالأعداد: $b = -4$ إذن $b^2 = 16$، و $4ac = 12$. يبقى $16 - 12 = 4$.",
        practice: SolverPractice(exercise: "حلّ المعادلة $3x^2 - 12x + 9 = 0$.", expected: "$x = 1$ أو $x = 3$")
    )

    private func thumbnail() -> Data? {
        let size = CGSize(width: 240, height: 160)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(white: 0.97, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Georgia", size: 24) ?? UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor(red: 0.12, green: 0.14, blue: 0.19, alpha: 1),
            ]
            ("Exercice 3" as NSString).draw(at: CGPoint(x: 16, y: 18), withAttributes: attributes)
            ("2x² − 8x + 6 = 0" as NSString).draw(at: CGPoint(x: 16, y: 82), withAttributes: attributes)
        }
        return image.jpegData(compressionQuality: 0.8)
    }

    private func session(_ sample: Sample, solved: Bool = true, revealed: Int = 3, help: Bool = false, practice: Bool = false) -> SolverSession {
        let exercise = SolvedExercise(statement: sample.statement, subject: .math, source: .camera, thumbnail: thumbnail())
        if solved {
            exercise.solutionRaw = sample.reply
            exercise.revealedSteps = revealed
            exercise.rewarded = true
        }
        if help { exercise.help = [1: sample.help] }
        if practice { exercise.practice = sample.practice }
        return SolverSession(exercise: exercise, quota: MikaQuota(defaults: freshDefaults()), xp: nil)
    }

    private func solutionScreen(_ session: SolverSession, bar: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            MicaboScreenHeader(title: solveText("solution.title"), eyebrow: session.exercise.subject.label, back: .back({}))
            SolverSolutionContent(session: session, isPro: false, actions: SolverSolutionActions())
            if bar {
                SolverSolutionBar(session: session, actions: SolverSolutionActions())
                    .padding(.top, 6)
            }
        }
        .padding(20)
        .environment(\.mikaStill, true)
    }

    private func capture(_ stage: SolverCaptureStage) -> some View {
        SolverCaptureChrome(
            stage: stage,
            frame: .constant(CGRect(x: 26, y: 248, width: 341, height: 160)),
            cameraAvailable: true,
            torchAvailable: true,
            torchOn: false,
            historyCount: 4,
            actions: SolverCaptureActions()
        ) {
            SolverDemoDesk()
        }
        .environment(\.mikaStill, true)
    }

    private func history() -> some View {
        let now = Date()
        let items = [
            SolverHistoryItem(statement: french.statement, subject: .math, date: now.addingTimeInterval(-600), thumbnail: thumbnail(), steps: 3, solved: true),
            SolverHistoryItem(statement: "Calculer la vitesse moyenne d'un cycliste qui parcourt 45 km en 1 h 30.", subject: .physics, date: now.addingTimeInterval(-86_400), steps: 2, solved: true),
            SolverHistoryItem(statement: "Expliquer le rôle des chloroplastes dans la photosynthèse.", subject: .biology, date: now.addingTimeInterval(-3 * 86_400), steps: 4, solved: true),
            SolverHistoryItem(statement: "Équilibrer l'équation : $CH_4 + O_2 \\rightarrow CO_2 + H_2O$", subject: .physics, date: now.addingTimeInterval(-5 * 86_400), steps: 0, solved: false),
        ]
        return VStack(alignment: .leading, spacing: 18) {
            MicaboScreenHeader(title: solveText("history.title"), eyebrow: solveText("history.count", ["count": "\(items.count)"]), back: .back({}))
            SolverHistoryContent(items: items, filter: .constant(nil))
        }
        .padding(20)
        .environment(\.mikaStill, true)
    }

    private func emptyHistory() -> some View {
        VStack(alignment: .leading, spacing: 18) {
            MicaboScreenHeader(title: solveText("history.title"), eyebrow: nil, back: .back({}))
            SolverHistoryContent(items: [], filter: .constant(nil))
        }
        .padding(20)
        .environment(\.mikaStill, true)
    }

    private func tutorHome() -> some View {
        let now = Date()
        let threads = [
            TutorThreadSummary(subject: .math, last: "$x = 1$ ou $x = 3$", date: now.addingTimeInterval(-600), count: 4),
            TutorThreadSummary(subject: .physics, last: "La vitesse moyenne, c'est la distance divisée par le temps.", date: now.addingTimeInterval(-86_400), count: 6),
            TutorThreadSummary(subject: .biology, last: nil, date: nil, count: 0),
            TutorThreadSummary(subject: .other, last: nil, date: nil, count: 0),
        ]
        return VStack(alignment: .leading, spacing: 18) {
            MicaboScreenHeader(title: solveText("tutor.title"), eyebrow: nil, back: .back({}))
            TutorHomeContent(threads: threads)
        }
        .padding(20)
        .environment(\.mikaStill, true)
    }

    private func thread(empty: Bool = false) -> some View {
        let bubbles = empty ? [] : [
            TutorBubble(role: .user, text: french.statement, exerciseID: UUID()),
            TutorBubble(role: .mika, text: "$x = 1$ ou $x = 3$", exerciseID: UUID()),
            TutorBubble(role: .user, text: "Pourquoi on divise par 2 au début ?"),
            TutorBubble(role: .mika, text: "Pour avoir des nombres plus petits ! L'équation garde les mêmes solutions quand on divise **les deux membres** par le même nombre :\n$$x^2 - 4x + 3 = 0$$"),
        ]
        return TutorThreadPreview(subject: .math, bubbles: bubbles, thinking: !empty)
            .environment(\.mikaStill, true)
    }

    // MARK: - Les rendus

    func testCapture() throws {
        try RenderGallery.render("solve-capture", height: 852, capture(.live))
        try RenderGallery.render("solve-capture-still", height: 852, capture(.reading))
        try RenderGallery.render("solve-unreadable", height: 852, night: true, capture(.unreadable))
    }

    func testSolution() async throws {
        try RenderGallery.render("solve-review", solutionScreen(session(french, solved: false), bar: true))
        try RenderGallery.render("solve-steps", night: true, solutionScreen(session(french, help: true)))
        try RenderGallery.render("solve-reveal", solutionScreen(session(french, revealed: 2), bar: true))
        try RenderGallery.render("solve-practice", night: true, solutionScreen(session(french, practice: true)))

        // La porte atteinte : la question offerte est passée, l'énoncé reste à l'écran.
        let quota = MikaQuota(defaults: freshDefaults())
        quota.noteAnswered()
        let locked = SolverSession(
            exercise: SolvedExercise(statement: french.statement, subject: .math, source: .camera, thumbnail: thumbnail()),
            quota: quota,
            xp: nil
        )
        await locked.solve(isPro: false, service: RenderStubAI(), context: nil)
        XCTAssertEqual(locked.phase, .locked)
        try RenderGallery.render("solve-paywall", night: true, solutionScreen(locked, bar: true))
    }

    func testHistoryAndTutor() throws {
        try RenderGallery.render("solve-history", night: true, history())
        try RenderGallery.render("solve-history-empty", emptyHistory())
        try RenderGallery.render("solve-tutor", night: true, tutorHome())
        try RenderGallery.render("solve-thread", height: 852, night: true, thread())
        try RenderGallery.render("solve-thread-empty", height: 852, thread(empty: true))
    }

    func testOtherLanguages() throws {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: UiLocale.storageKey)
        defer {
            if let previous { defaults.set(previous, forKey: UiLocale.storageKey) } else { defaults.removeObject(forKey: UiLocale.storageKey) }
        }
        defaults.set(UiLocale.de.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.render("solve-steps-de", solutionScreen(session(german, help: true)))
        try RenderGallery.render("solve-reveal-de", solutionScreen(session(german, revealed: 1), bar: true))
        try RenderGallery.render("solve-capture-de", height: 852, capture(.live))
        try RenderGallery.render("solve-tutor-de", tutorHome())
        defaults.set(UiLocale.fi.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.render("solve-capture-fi", height: 852, capture(.live))
        defaults.set(UiLocale.ar.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.render("solve-steps-ar", solutionScreen(session(arabic, help: true)).environment(\.layoutDirection, .rightToLeft))
        try RenderGallery.render("solve-capture-ar", height: 852, capture(.live).environment(\.layoutDirection, .rightToLeft))
        try RenderGallery.render("solve-tutor-ar", tutorHome().environment(\.layoutDirection, .rightToLeft))
        try RenderGallery.render("solve-history-ar", history().environment(\.layoutDirection, .rightToLeft))
    }
}

/// Le fil d'une matière, tel que l'écran le pose : son en-tête, les bulles et le champ.
private struct TutorThreadPreview: View {
    let subject: SolverSubject
    let bubbles: [TutorBubble]
    var thinking: Bool
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MicaboCircleIcon(systemImage: "chevron.backward", size: 38)
                SolverSubjectTile(subject: subject, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(subject.label)
                        .font(MicaboFont.ui(18, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                    Text(solveText("tutor.withMika"))
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.vertical, 10)
            TutorThreadContent(subject: subject, bubbles: bubbles, thinking: thinking)
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, 12)
            Spacer(minLength: 0)
            TutorInputBar(draft: $draft, thinking: false, focused: $focused) {}
        }
    }
}

private struct RenderStubAI: AIService {
    func generateCourse(_ request: CourseGenerationRequest) async throws -> GeneratedCourse { throw AIServiceError.notConfigured }
    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard] { throw AIServiceError.notConfigured }
    func explain(_ request: SelectionExplanationRequest) async throws -> SelectionExplanation { throw AIServiceError.notConfigured }
    func chat(_ request: MikaChatRequest) async throws -> MikaChatReply { throw AIServiceError.notConfigured }
}
