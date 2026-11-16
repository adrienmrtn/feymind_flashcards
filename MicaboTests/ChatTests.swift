import SwiftData
import UIKit
import XCTest
@testable import Micabo

/// **Le chat Mika du lot 11** : ce qui se garde (fils, messages, photos), les titres, le
/// document joint, la porte de Mika (une question par message, photos comprises), et la séance
/// liée à une leçon.
@MainActor
final class ChatTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "micabo.tests.chat.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: MicaboApp.schema,
            configurations: ModelConfiguration(schema: MicaboApp.schema, isStoredInMemoryOnly: true)
        )
        retained.append(container)
        return ModelContext(container)
    }

    private var retained: [ModelContainer] = []

    private func photoStore() -> ChatPhotoStore {
        ChatPhotoStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("chat-tests-\(UUID().uuidString)", isDirectory: true))
    }

    private func image() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
    }

    // MARK: - Les titres

    func testTheTitleIsTheFirstQuestionCutAtAWord() {
        XCTAssertEqual(ChatTitle.make(question: "C'est quoi une dérivée ?", photoCount: 0, courseTitle: nil, locale: .fr), "C'est quoi une dérivée ?")
        let long = "Comment on calcule la vitesse moyenne d'un cycliste qui roule pendant une heure et demie sur une route de montagne"
        let title = ChatTitle.make(question: long, photoCount: 0, courseTitle: nil, locale: .fr)
        XCTAssertTrue(title.hasSuffix("…"))
        XCTAssertLessThanOrEqual(title.count, ChatTitle.maxLength + 1)
        XCTAssertFalse(title.dropLast().hasSuffix(" "), "coupé au mot, sans espace avant les points")
        XCTAssertEqual(
            ChatTitle.make(question: "Explique la photosynthèse. Et aussi la respiration cellulaire, stp.", photoCount: 0, courseTitle: nil, locale: .fr),
            "Explique la photosynthèse."
        )
    }

    func testATitleWithoutQuestionComesFromThePhotosThenTheLesson() {
        XCTAssertEqual(ChatTitle.make(question: "  ", photoCount: 1, courseTitle: nil, locale: .fr), "Photo")
        XCTAssertEqual(ChatTitle.make(question: "", photoCount: 3, courseTitle: nil, locale: .fr), "3 photos")
        XCTAssertEqual(ChatTitle.make(question: "", photoCount: 0, courseTitle: "La Révolution française", locale: .fr), "La Révolution française")
        XCTAssertEqual(ChatTitle.make(question: "", photoCount: 0, courseTitle: nil, locale: .en), "New conversation")
        XCTAssertEqual(ChatTitle.make(question: "$x^2$ **vite**", photoCount: 0, courseTitle: nil, locale: .fr), "x^2 vite", "ni formules ni gras dans un titre")
    }

    // MARK: - Le magasin

    func testAThreadKeepsItsMessagesTitlePreviewAndCount() throws {
        let context = try context()
        let thread = ChatStore.createThread(origin: .home, in: context)
        ChatStore.append(.user, text: "Pourquoi le ciel est bleu ?", to: thread, in: context)
        ChatStore.append(.mika, text: "La lumière **bleue** se diffuse plus.", to: thread, in: context, now: Date().addingTimeInterval(5))

        XCTAssertEqual(thread.title, "Pourquoi le ciel est bleu ?")
        XCTAssertEqual(thread.messageCount, 2)
        XCTAssertEqual(thread.preview, "La lumière bleue se diffuse plus.")
        XCTAssertEqual(ChatStore.messages(of: thread.id, in: context).map(\.role), [.user, .mika])
        XCTAssertTrue(ChatStore.hasAny(in: context))

        // Une relance ne change pas le titre.
        ChatStore.append(.user, text: "Et le coucher de soleil ?", to: thread, in: context, now: Date().addingTimeInterval(10))
        XCTAssertEqual(thread.title, "Pourquoi le ciel est bleu ?")
    }

    func testRenamingFixesTheTitleAndBlankNamesAreIgnored() throws {
        let context = try context()
        let thread = ChatStore.createThread(origin: .home, in: context)
        ChatStore.rename(thread, to: "   ", in: context)
        XCTAssertFalse(thread.titleIsCustom)
        ChatStore.rename(thread, to: " Maths DM ", in: context)
        XCTAssertEqual(thread.title, "Maths DM")
        XCTAssertTrue(thread.titleIsCustom)
        ChatStore.append(.user, text: "Une question", to: thread, in: context)
        XCTAssertEqual(thread.title, "Maths DM", "un titre choisi ne se réécrit pas")
    }

    func testDeletingAThreadRemovesItsMessagesAndPhotos() throws {
        let context = try context()
        let store = photoStore()
        let name = try XCTUnwrap(store.save(image()))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url(for: name).path))
        let thread = ChatStore.createThread(origin: .camera, in: context)
        ChatStore.append(.user, text: "", photoNames: [name], photoTexts: ["x = 2"], to: thread, in: context)
        let other = ChatStore.createThread(origin: .home, in: context)
        ChatStore.append(.user, text: "Autre", to: other, in: context)

        ChatStore.delete(thread, in: context, photos: store)

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(for: name).path))
        XCTAssertEqual(ChatStore.threads(in: context).map(\.id), [other.id])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ChatMessage>()), 1)
    }

    func testAPhotoOnlyMessageIsTitledAndKeepsWhatWasRead() throws {
        let context = try context()
        let thread = ChatStore.createThread(origin: .camera, in: context)
        let message = ChatStore.append(.user, text: "", photoNames: ["a.jpg", "b.jpg"], photoTexts: ["page 1", "page 2"], to: thread, in: context)
        XCTAssertEqual(thread.title, L10n.t("ios.chat11.title.photos", locale: .resolved(), vars: ["count": "2"]))
        XCTAssertEqual(message.photoNames, ["a.jpg", "b.jpg"])
        XCTAssertEqual(message.photoTexts, ["page 1", "page 2"])
    }

    func testSearchIgnoresCaseAndAccents() throws {
        let context = try context()
        let a = ChatStore.createThread(origin: .home, in: context)
        ChatStore.append(.user, text: "Le théorème de Thalès", to: a, in: context)
        let b = ChatStore.createThread(origin: .home, in: context)
        ChatStore.append(.user, text: "La Révolution", to: b, in: context)
        let threads = ChatStore.threads(in: context)
        XCTAssertEqual(ChatStore.search(threads, query: "THEOREME").map(\.id), [a.id])
        XCTAssertEqual(ChatStore.search(threads, query: "revolution").map(\.id), [b.id])
        XCTAssertEqual(ChatStore.search(threads, query: "  ").count, 2)
    }

    func testTheLatestLessonThreadIsResumed() throws {
        let context = try context()
        let course = UUID()
        let old = ChatStore.createThread(origin: .lesson, courseID: course, in: context, now: Date().addingTimeInterval(-100))
        let recent = ChatStore.createThread(origin: .lesson, courseID: course, in: context)
        _ = ChatStore.createThread(origin: .home, in: context)
        XCTAssertEqual(ChatStore.latestThread(forCourse: course, in: context)?.id, recent.id)
        XCTAssertNotEqual(old.id, recent.id)
    }

    func testARescannedExerciseReplacesItsMessages() throws {
        let context = try context()
        let id = UUID()
        ChatStore.recordExercise(id: id, statement: "2x = 8", answer: "x = 4", in: context)
        ChatStore.recordExercise(id: id, statement: "2x = 10", answer: "x = 5", in: context)
        let thread = try XCTUnwrap(ChatStore.thread(forExercise: id, in: context))
        XCTAssertEqual(ChatStore.messages(of: thread.id, in: context).map(\.text), ["2x = 10", "x = 5"])
        XCTAssertEqual(thread.messageCount, 2)
        XCTAssertEqual(thread.origin, .scan)
        XCTAssertEqual(ChatStore.threads(in: context).count, 1)
    }

    func testHistoryGroupsByDay() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let dates = [now, now.addingTimeInterval(-86_400), now.addingTimeInterval(-3 * 86_400), now.addingTimeInterval(-40 * 86_400)]
        let groups = ChatHistorySection.group(dates, date: { $0 }, now: now, calendar: calendar)
        XCTAssertEqual(groups.count, 4)
        XCTAssertEqual(groups[0].0, .today)
        XCTAssertEqual(groups[1].0, .yesterday)
        XCTAssertEqual(groups[2].0, .week)
        XCTAssertEqual(groups[3].0, .older, "plus d'une semaine : « plus ancien »")
    }

    // MARK: - Le document joint

    func testTheDocumentNumbersPhotosAndStaysWithinTheServerLimit() {
        let photos = (1...4).map { ChatDocument.Photo(number: $0, text: String(repeating: "\($0)", count: 6_000)) }
        let payload = ChatDocument.payload(photos: photos, contextTitle: "Leçon", contextText: String(repeating: "c", count: 9_000), locale: .fr)
        let text = payload?.text ?? ""
        XCTAssertLessThanOrEqual(text.count, MikaLimits.attachmentCharacters)
        XCTAssertTrue(text.contains("Photo 4"), "la plus récente passe d'abord")
        XCTAssertFalse(text.contains("Photo 1\n"), "la plus ancienne tombe quand tout ne tient pas")
        let photo3 = text.range(of: "Photo 3")
        let photo4 = text.range(of: "Photo 4")
        XCTAssertNotNil(photo3)
        XCTAssertLessThan(photo3!.lowerBound, photo4!.lowerBound, "remises dans l'ordre")
    }

    func testTheDocumentCarriesTheLessonWhenThereIsNoPhoto() {
        let payload = ChatDocument.payload(photos: [], contextTitle: "Les fractions", contextText: "Une fraction est…", locale: .fr)
        XCTAssertEqual(payload?.title, "Les fractions")
        XCTAssertTrue(payload?.text.contains("Une fraction est…") ?? false)
        XCTAssertNil(ChatDocument.payload(photos: [ChatDocument.Photo(number: 1, text: " ")], contextTitle: nil, contextText: nil, locale: .fr))
    }

    // MARK: - La porte de Mika

    func testSeveralPhotosAreOneQuestionAndTheSecondNeedsPro() async throws {
        let context = try context()
        let quota = MikaQuota(defaults: freshDefaults())
        let ai = ChatStubAI()
        let session = ChatSession(launch: ChatLaunch(origin: .camera), context: context, quota: quota, xp: nil, photos: photoStore(), recognize: { _ in "Exercice 2 : résoudre 3x + 1 = 7" })
        session.add(photos: [image(), image()])
        for _ in 0..<200 where session.isReading { await Task.yield() }
        XCTAssertFalse(session.isReading)
        XCTAssertTrue(session.canSend)

        await session.send(isPro: false, service: ai, context: context)

        XCTAssertEqual(ai.requests.count, 1, "deux photos, une seule question")
        let request = try XCTUnwrap(ai.requests.first)
        XCTAssertEqual(request.turns.last?.role, .user)
        XCTAssertFalse(request.turns.last?.text.isEmpty ?? true, "une question faite de photos seules dit quoi faire")
        XCTAssertTrue(request.attachment?.text.contains("3x + 1 = 7") ?? false)
        XCTAssertEqual(session.bubbles.map(\.role), [.user, .mika])
        XCTAssertEqual(session.bubbles.first?.photoNames.count, 2)
        XCTAssertTrue(session.pending.isEmpty)
        XCTAssertFalse(quota.hasFreeQuestion)

        session.draft = "Et la suivante ?"
        await session.send(isPro: false, service: ai, context: context)
        XCTAssertEqual(ai.requests.count, 1, "la deuxième question n'est pas envoyée")
        XCTAssertTrue(session.limitReached)
        XCTAssertEqual(session.paywall, .mika)
        XCTAssertEqual(session.draft, "Et la suivante ?", "la question reste dans le champ")
        XCTAssertEqual(ChatStore.threads(in: context).count, 1)
    }

    func testANetworkFailureKeepsTheQuestionAndDoesNotSpendIt() async throws {
        let context = try context()
        let quota = MikaQuota(defaults: freshDefaults())
        let session = ChatSession(launch: ChatLaunch(origin: .home), context: context, quota: quota, xp: nil, photos: photoStore())
        session.draft = "C'est quoi un vecteur ?"
        await session.send(isPro: false, service: ChatFailingAI(), context: context)
        XCTAssertNotNil(session.failure)
        XCTAssertTrue(session.canRetry)
        XCTAssertTrue(quota.hasFreeQuestion, "une panne ne brûle pas la question offerte")
        XCTAssertEqual(session.bubbles.map(\.role), [.user])

        let ai = ChatStubAI()
        await session.retry(isPro: false, service: ai, context: context)
        XCTAssertNil(session.failure)
        XCTAssertEqual(session.bubbles.map(\.role), [.user, .mika])
        XCTAssertEqual(ai.requests.first?.turns.map(\.text), ["C'est quoi un vecteur ?"])
    }

    func testAProUserHitsTheDailyCapBeforeTheCall() async throws {
        let context = try context()
        let defaults = freshDefaults()
        let quota = MikaQuota(defaults: defaults)
        for _ in 0..<MikaAllowance.proMessagesPerDay { quota.noteAnswered() }
        let ai = ChatStubAI()
        let session = ChatSession(launch: ChatLaunch(origin: .home), context: context, quota: quota, xp: nil, photos: photoStore())
        session.draft = "Encore une"
        await session.send(isPro: true, service: ai, context: context)
        XCTAssertTrue(session.capReached)
        XCTAssertTrue(ai.requests.isEmpty)
        XCTAssertNil(session.paywall, "le plafond d'un abonné n'ouvre pas le paywall")
        XCTAssertTrue(ChatStore.threads(in: context).isEmpty, "rien d'envoyé, rien de gardé")
    }

    func testOpeningAndLeavingAnEmptyChatLeavesNothingInTheHistory() throws {
        let context = try context()
        let session = ChatSession(launch: ChatLaunch(origin: .home, prefill: "Bonjour"), context: context, xp: nil, photos: photoStore())
        XCTAssertEqual(session.draft, "Bonjour")
        session.add(photos: [])
        XCTAssertTrue(ChatStore.threads(in: context).isEmpty)
    }

    func testAPhotoRemovedBeforeSendingDoesNotLeave() async throws {
        let context = try context()
        let ai = ChatStubAI()
        let session = ChatSession(launch: ChatLaunch(origin: .camera), context: context, quota: MikaQuota(defaults: freshDefaults()), xp: nil, photos: photoStore(), recognize: { _ in "texte lu sur la photo" })
        session.add(photos: [image(), image(), image()])
        XCTAssertEqual(session.pending.count, 3)
        session.remove(photo: session.pending[1].id)
        for _ in 0..<200 where session.isReading { await Task.yield() }
        await session.send(isPro: true, service: ai, context: context)
        XCTAssertEqual(session.bubbles.first?.photoNames.count, 2)
    }

    func testNoMoreThanSixPhotosWait() throws {
        let session = ChatSession(launch: ChatLaunch(origin: .camera), context: nil, xp: nil, photos: photoStore(), recognize: { _ in "" })
        session.add(photos: Array(repeating: image(), count: 9))
        XCTAssertEqual(session.pending.count, ChatSession.maxPhotos)
        XCTAssertFalse(session.hasRoomForPhotos)
    }

    func testAnUnreadablePhotoIsSaidButDoesNotBlock() {
        let session = ChatSession(launch: ChatLaunch(origin: .camera), context: nil, xp: nil, photos: photoStore(), recognize: { _ in "" })
        session.add(photos: [image()])
        session.finishReading(session.pending[0].id, text: "  ")
        XCTAssertEqual(session.pending[0].state, .unreadable)
        XCTAssertTrue(session.canSend)
    }

    func testMakeALessonIsOfferedOnlyOutsideALesson() async throws {
        let context = try context()
        let session = ChatSession(launch: ChatLaunch(origin: .home), context: context, quota: MikaQuota(defaults: freshDefaults()), xp: nil, photos: photoStore())
        XCTAssertNil(session.lessonTopic, "pas avant une réponse")
        session.draft = "Les volcans"
        await session.send(isPro: true, service: ChatStubAI(), context: context)
        XCTAssertEqual(session.lessonTopic, "Les volcans")

        let linked = ChatSession(preview: [ChatBubble(role: .user, text: "Q"), ChatBubble(role: .mika, text: "R")], courseTitle: "Les volcans")
        XCTAssertNil(linked.lessonTopic, "dans une leçon, pas de leçon à créer")
    }

    // MARK: - La migration

    func testOldThreadsJoinTheHistoryOnce() throws {
        let context = try context()
        let defaults = freshDefaults()
        context.insert(TutorMessage(subject: .math, role: .user, text: "2 + 2 ?"))
        context.insert(TutorMessage(subject: .math, role: .mika, text: "4", createdAt: Date().addingTimeInterval(1)))
        try context.save()
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        ChatMigration.runIfNeeded(in: context, defaults: defaults, lessonsDirectory: empty)
        ChatMigration.runIfNeeded(in: context, defaults: defaults, lessonsDirectory: empty)
        let threads = ChatStore.threads(in: context)
        XCTAssertEqual(threads.count, 1)
        XCTAssertEqual(threads.first?.title, SolverSubject.math.label)
        XCTAssertEqual(threads.first?.messageCount, 2)
    }

    // MARK: - Les entrées

    /// Lot 12 : les conversations ont leur tiroir (le bouton menu de la Home) ; la puce
    /// « Mes questions » ne double plus ce chemin.
    func testTheConversationsLiveInTheDrawerNotInAChip() {
        XCTAssertFalse(HomeShortcut.available(isNewcomer: false, hasLesson: true, dueCount: 0).contains(.chats))
        XCTAssertFalse(HomeShortcut.available(isNewcomer: true, hasLesson: false, dueCount: 0).contains(.chats))
        XCTAssertEqual(HomeShortcut.chats.title(locale: .fr), "Mes questions")
    }

    func testChatEventNamesCarryNoText() {
        for event in [AnalyticsEvent.chatOpened, .chatSent, .chatHistoryOpened, .chatGateway, .focusLessonOpened] {
            XCTAssertTrue(event.rawValue.hasPrefix("chat_") || event.rawValue.hasPrefix("focus_"))
        }
        XCTAssertEqual(Set(ChatOrigin.allCases.map(\.rawValue)).count, ChatOrigin.allCases.count)
    }

    // MARK: - La séance liée à une leçon

    func testAFocusPlanLearnsItsLessonByDefault() {
        let plan = FocusPlan(workMinutes: 25, courseID: UUID(), courseTitle: "Les fractions")
        XCTAssertEqual(plan.activity, .lesson)
        XCTAssertEqual(FocusActivity.allCases.map(\.rawValue), ["lesson", "cards", "quiz"])
    }

    func testTheFocusOutcomeSaysWhatWasDone() {
        let nothing = FocusOutcome(lessonTitle: "Les fractions", minutes: 25)
        XCTAssertTrue(nothing.lines.isEmpty)
        let done = FocusOutcome(lessonTitle: "Les fractions", minutes: 25, steps: 2, cards: 12, quizzes: 1)
        XCTAssertEqual(done.lines.count, 3)
        XCTAssertEqual(L10n.t("ios.chat11.focus.summary.minutes", locale: .fr, vars: ["minutes": "25", "lesson": "Les fractions"]), "25 min sur Les fractions")
    }
}

// MARK: - Les doublures

private final class ChatStubAI: AIService {
    var requests: [MikaChatRequest] = []

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
        requests.append(request)
        return MikaChatReply(reply: "Voici la réponse.", card: GeneratedFlashcard(front: "Q", back: "R"))
    }
}

private struct ChatFailingAI: AIService {
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
