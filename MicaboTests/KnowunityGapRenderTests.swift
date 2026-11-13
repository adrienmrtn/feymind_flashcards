import SwiftUI
import XCTest
@testable import Micabo

/// **Les rendus du lot 7 « tout Knowunity »** : « Corriger un texte » (saisie, relecture en
/// cours, relecture, porte) et l'aide aux devoirs sur une question d'histoire, de jour, de
/// nuit, en allemand et en arabe.
@MainActor
final class KnowunityGapRenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
    }

    private func freshDefaults() -> UserDefaults {
        let name = "micabo.tests.ku7.render.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func withLocale(_ locale: UiLocale, _ body: () async throws -> Void) async rethrows {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: UiLocale.storageKey)
        defaults.set(locale.rawValue, forKey: UiLocale.storageKey)
        defer {
            if let previous { defaults.set(previous, forKey: UiLocale.storageKey) } else { defaults.removeObject(forKey: UiLocale.storageKey) }
        }
        try await body()
    }

    // MARK: - Les contenus

    private struct Sample {
        var text: String
        var reply: String
    }

    private let french = Sample(
        text: "Hier, je suis aller au cinema avec mes amis. Le film étais vraiment bien, mais la fin était trop rapide. Après, nous avons manger une pizza.",
        reply: """
        [SUMMARY] Ton récit est clair et vivant. Attention aux terminaisons des verbes : c'est là que sont presque toutes tes fautes.
        [FIX] je suis aller
        => je suis allé
        Avec « être », on écrit le participe passé (-é), pas l'infinitif (-er).
        [FIX] cinema
        => cinéma
        Le mot prend un accent aigu sur le e.
        [FIX] Le film étais
        => Le film était
        À la 3e personne du singulier, l'imparfait se termine en -ait.
        [FIX] nous avons manger
        => nous avons mangé
        Après « avoir », c'est aussi le participe passé.
        [TIP] Remplace le verbe par « vendre » : si tu dirais « vendu », écris -é.
        """
    )

    private let german = Sample(
        text: "Gestern bin ich mit meine Freunde ins Kino gegangen. Der Film war sehr spannent, aber das Ende war zu schnell.",
        reply: """
        [SUMMARY] Dein Text ist klar und gut erzählt. Achte vor allem auf die Fälle nach Präpositionen.
        [FIX] mit meine Freunde
        => mit meinen Freunden
        Nach „mit“ steht immer der Dativ, im Plural mit -n am Ende.
        [FIX] spannent
        => spannend
        Das Partizip I endet auf -end.
        [TIP] Lies jeden Satz mit einer Präposition noch einmal und frag dich, welcher Fall danach kommt.
        """
    )

    private let arabic = Sample(
        text: "ذهبت امس مع اصدقائي الى السينما. كان الفيلم جميلا جدا لكن النهايه كانت سريعة.",
        reply: """
        [SUMMARY] نصك واضح ومرتّب. انتبه إلى الهمزات والتاء المربوطة.
        [FIX] امس
        => أمس
        تُكتب همزة القطع في أول الكلمة.
        [FIX] النهايه
        => النهاية
        الكلمة مؤنثة فتنتهي بتاء مربوطة.
        [TIP] اقرأ نصك بصوت عالٍ لتسمع الهمزات قبل أن تكتبها.
        """
    )

    private func reviewed(_ sample: Sample) async -> WritingSession {
        let session = WritingSession(text: sample.text, quota: MikaQuota(defaults: freshDefaults()), xp: nil)
        await session.check(isPro: true, service: StubAI(text: sample.reply))
        XCTAssertEqual(session.phase, .reviewed)
        return session
    }

    private func screen(_ session: WritingSession, isPro: Bool = false, bar: Bool = true) -> some View {
        WritingPreview(session: session, isPro: isPro, bar: bar)
            .environment(\.mikaStill, true)
    }

    // MARK: - Corriger un texte

    func testWritingCoach() async throws {
        try RenderGallery.render("ku-writing-empty", height: 852, night: true, screen(WritingSession(quota: MikaQuota(defaults: freshDefaults()), xp: nil)))
        try RenderGallery.render("ku-writing-typed", height: 852, screen(WritingSession(text: french.text, quota: MikaQuota(defaults: freshDefaults()), xp: nil), isPro: true))

        let checking = WritingSession(text: french.text, quota: MikaQuota(defaults: freshDefaults()), xp: nil)
        let slow = SlowAI()
        let task = Task { await checking.check(isPro: true, service: slow) }
        for _ in 0..<20 where checking.phase != .checking {
            await Task.yield()
        }
        XCTAssertEqual(checking.phase, .checking)
        try RenderGallery.render("ku-writing-checking", height: 852, night: true, screen(checking, bar: false))
        task.cancel()

        try RenderGallery.render("ku-writing-review", night: true, screen(await reviewed(french)))

        let used = MikaQuota(defaults: freshDefaults())
        used.noteAnswered()
        let locked = WritingSession(text: french.text, quota: used, xp: nil)
        await locked.check(isPro: false, service: StubAI(text: french.reply))
        XCTAssertEqual(locked.phase, .locked)
        try RenderGallery.render("ku-writing-locked", height: 852, night: true, screen(locked))
    }

    func testWritingCoachInOtherLanguages() async throws {
        try await withLocale(.de) {
            try RenderGallery.render("ku-writing-empty-de", height: 852, screen(WritingSession(quota: MikaQuota(defaults: freshDefaults()), xp: nil)))
            try RenderGallery.render("ku-writing-review-de", screen(await reviewed(german)))
        }
        try await withLocale(.fi) {
            try RenderGallery.render("ku-writing-empty-fi", height: 852, screen(WritingSession(quota: MikaQuota(defaults: freshDefaults()), xp: nil)))
        }
        try await withLocale(.ar) {
            try RenderGallery.render("ku-writing-empty-ar", height: 852, screen(WritingSession(quota: MikaQuota(defaults: freshDefaults()), xp: nil)).environment(\.layoutDirection, .rightToLeft))
            try RenderGallery.render("ku-writing-review-ar", night: true, screen(await reviewed(arabic)).environment(\.layoutDirection, .rightToLeft))
        }
    }

    /// Le plus petit iPhone et le plus grand texte : rien ne coupe.
    func testWritingCoachAtTheLargestTextOnTheSmallestPhone() async throws {
        try RenderGallery.render(
            "ku-writing-review-se-xxxl",
            width: 375,
            screen(await reviewed(french)).environment(\.dynamicTypeSize, .xxxLarge)
        )
    }

    // MARK: - L'aide aux devoirs, toutes matières

    private func homework(_ statement: String, subject: SolverSubject, reply: String) -> some View {
        let exercise = SolvedExercise(statement: statement, subject: subject, source: .typed, thumbnail: nil)
        exercise.solutionRaw = reply
        exercise.revealedSteps = 3
        exercise.rewarded = true
        let session = SolverSession(exercise: exercise, quota: MikaQuota(defaults: freshDefaults()), xp: nil)
        return VStack(alignment: .leading, spacing: 18) {
            MicaboScreenHeader(title: solveText("solution.title"), eyebrow: session.exercise.subject.label, back: .back({}))
            SolverSolutionContent(session: session, isPro: true, actions: SolverSolutionActions())
        }
        .padding(20)
        .environment(\.mikaStill, true)
    }

    func testHomeworkInEverySubject() async throws {
        try RenderGallery.render("ku-homework-history", night: true, homework(
            "Quelles sont les causes de la Première Guerre mondiale ?",
            subject: .humanities,
            reply: """
            [SUBJECT] humanities
            [STEP] Les rivalités entre puissances
            En 1914, l'Europe est divisée en deux blocs : la **Triple Entente** et la **Triple Alliance**. Chaque pays craint l'autre et s'arme.
            [STEP] Les nationalismes
            Les peuples des Balkans veulent leur indépendance, et la France veut reprendre l'Alsace-Moselle.
            [STEP] L'étincelle de Sarajevo
            Le 28 juin 1914, l'assassinat de l'archiduc François-Ferdinand déclenche le jeu des alliances.
            [ANSWER] Des alliances rivales, des nationalismes forts et l'attentat de Sarajevo comme déclencheur.
            """
        ))
        try await withLocale(.de) {
            try RenderGallery.render("ku-homework-language-de", homework(
                "Wann benutzt man den Konjunktiv II?",
                subject: .languages,
                reply: """
                [SUBJECT] languages
                [STEP] Wünsche ausdrücken
                Mit dem Konjunktiv II sagst du, was nicht wirklich ist: *Ich hätte gern mehr Zeit.*
                [STEP] Höfliche Bitten
                Er macht eine Bitte freundlicher: *Könntest du mir helfen?*
                [STEP] Irreale Bedingungen
                Nach „wenn“ beschreibt er eine Situation, die nicht eintritt: *Wenn ich Zeit hätte, käme ich.*
                [ANSWER] Für Wünsche, höfliche Bitten und irreale Bedingungen.
                """
            ))
        }
        try await withLocale(.ar) {
            try RenderGallery.render("ku-homework-history-ar", homework(
                "ما أسباب الحرب العالمية الأولى؟",
                subject: .humanities,
                reply: """
                [SUBJECT] humanities
                [STEP] التنافس بين القوى
                في عام 1914 انقسمت أوروبا إلى حلفين متنافسين، وكانت كل دولة تتسلّح.
                [STEP] النزعات القومية
                أرادت شعوب البلقان الاستقلال، وأرادت فرنسا استعادة الألزاس.
                [STEP] شرارة سراييفو
                اغتيال ولي عهد النمسا في 28 يونيو 1914 أشعل لعبة التحالفات.
                [ANSWER] تحالفات متنافسة ونزعات قومية قوية، ثم اغتيال سراييفو كشرارة.
                """
            ).environment(\.layoutDirection, .rightToLeft))
        }
    }
}

/// L'écran tel que `WritingCoachView` le pose : l'en-tête, le contenu, et le bouton du bas.
private struct WritingPreview: View {
    let session: WritingSession
    var isPro: Bool
    var bar: Bool
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            MicaboScreenHeader(title: writingText("ios.ku7.writing.title"), back: .close({}))
            WritingCoachContent(session: session, isPro: isPro, focused: $focused, actions: WritingCoachActions(), editorStandIn: true)
            Spacer(minLength: 0)
            if bar {
                WritingCoachBar(session: session, actions: WritingCoachActions())
            }
        }
        .padding(20)
    }
}

private struct StubAI: AIService {
    let text: String
    func generateCourse(_ request: CourseGenerationRequest) async throws -> GeneratedCourse { throw AIServiceError.notConfigured }
    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard] { throw AIServiceError.notConfigured }
    func explain(_ request: SelectionExplanationRequest) async throws -> SelectionExplanation { throw AIServiceError.notConfigured }
    func chat(_ request: MikaChatRequest) async throws -> MikaChatReply { MikaChatReply(reply: text, card: nil) }
}

/// Un service qui ne répond pas tout de suite : la relecture reste « en cours » le temps du rendu.
private struct SlowAI: AIService {
    func generateCourse(_ request: CourseGenerationRequest) async throws -> GeneratedCourse { throw AIServiceError.notConfigured }
    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard] { throw AIServiceError.notConfigured }
    func explain(_ request: SelectionExplanationRequest) async throws -> SelectionExplanation { throw AIServiceError.notConfigured }
    func chat(_ request: MikaChatRequest) async throws -> MikaChatReply {
        try await Task.sleep(for: .seconds(30))
        throw AIServiceError.notConfigured
    }
}
