import XCTest
@testable import Micabo

/// **Mika, l'onglet : ce que la porte laisse passer, et ce que la conversation garde.**
final class MikaTests: XCTestCase {
    /// Des réglages à part, vierges à chaque test : la porte de Mika ne doit lire que les siens.
    private func freshDefaults() -> UserDefaults {
        let name = "micabo.tests.mika.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - La porte

    /// **Une question offerte, une seule, puis Premium.** Et elle ne se consomme qu'une fois
    /// la réponse arrivée.
    func testTheFirstQuestionIsFreeThenPremium() {
        let quota = MikaQuota(defaults: freshDefaults())
        XCTAssertTrue(quota.hasFreeQuestion)
        XCTAssertEqual(quota.gate(isPro: false), .allowed)

        quota.noteAnswered()
        XCTAssertFalse(quota.hasFreeQuestion)
        XCTAssertEqual(quota.gate(isPro: false), .paywall, "La deuxième question est dans Premium")
        XCTAssertEqual(MikaAllowance.freeQuestions, 1)
    }

    /// **Un abonné a un plafond par jour**, invisible tant qu'il n'est pas atteint, et il se
    /// remet à minuit chez lui.
    func testAProUserHasADailyCapThatResetsTheNextDay() {
        var day = Date(timeIntervalSince1970: 1_800_000_000)
        let quota = MikaQuota(defaults: freshDefaults(), now: { day })

        for _ in 0..<MikaAllowance.proMessagesPerDay {
            XCTAssertEqual(quota.gate(isPro: true), .allowed)
            quota.noteAnswered()
        }
        XCTAssertEqual(quota.askedToday, MikaAllowance.proMessagesPerDay)
        XCTAssertEqual(quota.gate(isPro: true), .dailyCapReached)

        day = day.addingTimeInterval(24 * 3600)
        XCTAssertEqual(quota.askedToday, 0, "Le lendemain repart de zéro")
        XCTAssertEqual(quota.gate(isPro: true), .allowed)
    }

    /// Le plafond de l'app est celui du serveur : le refus doit arriver avant l'appel, pas
    /// après.
    func testTheProCapMatchesTheServer() {
        XCTAssertEqual(MikaAllowance.proMessagesPerDay, 30)
        XCTAssertEqual(MikaLimits.turns, 8)
        XCTAssertEqual(MikaLimits.attachmentCharacters, 16_000)
    }

    // MARK: - La conversation

    /// **La question part, la réponse s'ajoute, la carte reste avec elle**, et le fil est
    /// écrit à chaque pas.
    @MainActor
    func testAnAnswerIsAppendedWithItsCardAndPersisted() async {
        var saved: [MikaConversation] = []
        let chat = MikaChat(conversation: MikaConversation(), quota: MikaQuota(defaults: freshDefaults()), store: { saved.append($0) })
        chat.draft = "C'est quoi une dérivée ?"

        let gate = await chat.send(isPro: false, level: nil, language: .fr, using: CannedAIService(reply: MikaChatReply(
            reply: "La pente de la tangente.",
            card: GeneratedFlashcard(front: "Que mesure f'(a) ?", back: "La pente de la tangente en a.")
        )))

        XCTAssertEqual(gate, .allowed)
        XCTAssertEqual(chat.messages.count, 2)
        XCTAssertEqual(chat.messages.first?.role, .user)
        XCTAssertEqual(chat.messages.last?.role, .mika)
        XCTAssertEqual(chat.messages.last?.card?.front, "Que mesure f'(a) ?")
        XCTAssertEqual(chat.draft, "", "Le champ se vide au départ")
        XCTAssertFalse(chat.quota.hasFreeQuestion, "La question offerte est passée")
        XCTAssertEqual(saved.count, 2, "Écrit au départ et à l'arrivée")
        XCTAssertNil(chat.failure)
    }

    /// **Une panne ne brûle pas la question offerte**, et laisse le message en place pour
    /// réessayer.
    @MainActor
    func testAFailedAnswerKeepsTheFreeQuestionAndOffersARetry() async {
        let chat = MikaChat(conversation: MikaConversation(), quota: MikaQuota(defaults: freshDefaults()), store: { _ in })
        chat.draft = "Bonjour"

        await chat.send(isPro: false, level: nil, language: .fr, using: FailingAIService())

        XCTAssertEqual(chat.messages.count, 1, "Le message de l'élève reste")
        XCTAssertNotNil(chat.failure)
        XCTAssertTrue(chat.canRetry)
        XCTAssertTrue(chat.quota.hasFreeQuestion, "Pas de réponse, pas de question consommée")

        await chat.retry(level: nil, language: .fr, using: CannedAIService(reply: MikaChatReply(reply: "Salut !", card: nil)))
        XCTAssertEqual(chat.messages.count, 2)
        XCTAssertNil(chat.failure)
        XCTAssertFalse(chat.quota.hasFreeQuestion)
    }

    /// **Sans question offerte, rien ne part** : la porte rend le paywall, le champ garde le
    /// texte.
    @MainActor
    func testWithoutAFreeQuestionTheGateReturnsThePaywall() async {
        let defaults = freshDefaults()
        MikaQuota(defaults: defaults).noteAnswered()
        let chat = MikaChat(conversation: MikaConversation(), quota: MikaQuota(defaults: defaults), store: { _ in })
        chat.draft = "Encore une"

        let gate = await chat.send(isPro: false, level: nil, language: .fr, using: FailingAIService())

        XCTAssertEqual(gate, .paywall)
        XCTAssertTrue(chat.messages.isEmpty)
        XCTAssertEqual(chat.draft, "Encore une")
    }

    /// **Seuls les huit derniers tours voyagent**, chacun borné : le centième message coûte
    /// ce que coûte le premier.
    @MainActor
    func testOnlyTheLastTurnsTravel() {
        var conversation = MikaConversation()
        for index in 0..<20 {
            conversation.messages.append(MikaMessage(
                role: index % 2 == 0 ? .user : .mika,
                text: String(repeating: "x", count: 2_000) + "\(index)"
            ))
        }
        let chat = MikaChat(conversation: conversation, quota: MikaQuota(defaults: freshDefaults()), store: { _ in })

        let turns = chat.turns
        XCTAssertEqual(turns.count, MikaLimits.turns)
        XCTAssertTrue(turns.allSatisfy { $0.text.count <= MikaLimits.messageCharacters })
        XCTAssertEqual(turns.last?.role, .mika, "Le dernier tour est le dernier message")

        let request = MikaChatRequest(turns: conversation.messages.map { MikaTurn(role: $0.role, text: $0.text) })
        XCTAssertEqual(request.trimmedTurns.count, MikaLimits.turns)
    }

    /// **La conversation survit à un relancement**, pièce jointe comprise.
    func testTheConversationSurvivesARestart() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mika-tests-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        var conversation = MikaConversation()
        conversation.messages = [
            MikaMessage(role: .user, text: "Bonjour"),
            MikaMessage(role: .mika, text: "Salut !", cardFront: "Q ?", cardBack: "R.", cardAdded: true),
        ]
        conversation.attachment = MikaAttachment(kind: .course, title: "Les dérivées", text: "Le nombre dérivé…", courseID: UUID(), emoji: "📐")

        MikaConversationStore.save(conversation, to: url)
        XCTAssertEqual(MikaConversationStore.load(from: url), conversation)
        XCTAssertEqual(MikaConversationStore.load(from: url.appendingPathExtension("absent")), MikaConversation())
    }

    /// Une nouvelle conversation efface le fil et la pièce jointe, et rien d'autre.
    @MainActor
    func testANewConversationClearsTheThreadNotTheFreeQuestion() {
        let defaults = freshDefaults()
        MikaQuota(defaults: defaults).noteAnswered()
        var conversation = MikaConversation()
        conversation.messages = [MikaMessage(role: .user, text: "Bonjour")]
        conversation.attachment = MikaAttachment(kind: .document, title: "Doc", text: "…")
        let chat = MikaChat(conversation: conversation, quota: MikaQuota(defaults: defaults), store: { _ in })

        chat.reset()

        XCTAssertTrue(chat.isEmpty)
        XCTAssertNil(chat.attachment)
        XCTAssertFalse(chat.quota.hasFreeQuestion, "La question offerte ne revient pas")
    }
}

// MARK: - Les doublures

private struct CannedAIService: AIService {
    let reply: MikaChatReply

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
        reply
    }
}

private struct FailingAIService: AIService {
    func generateCourse(_ request: CourseGenerationRequest) async throws -> GeneratedCourse {
        throw AIServiceError.network("hors ligne")
    }

    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard] {
        throw AIServiceError.network("hors ligne")
    }

    func explain(_ request: SelectionExplanationRequest) async throws -> SelectionExplanation {
        throw AIServiceError.network("hors ligne")
    }

    func chat(_ request: MikaChatRequest) async throws -> MikaChatReply {
        throw AIServiceError.network("hors ligne")
    }
}
