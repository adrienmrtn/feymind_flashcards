import SwiftData
import UIKit
import XCTest
@testable import Micabo

/// **La caméra à modes, la feuille Outils et le tiroir des conversations** (lot 12) : les modes
/// et leurs consignes, la mémoire du mode, la lampe, les cartes d'un vocabulaire, une capture
/// qui part en une question, le rangement de l'historique, les entrées de la feuille Outils.
@MainActor
final class Scan12Tests: XCTestCase {
    private let languages: [UiLocale] = [.fr, .en, .de, .es, .tr, .ar]

    private func freshDefaults() -> UserDefaults {
        let name = "micabo.tests.scan12.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private var retained: [ModelContainer] = []

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: MicaboApp.schema,
            configurations: ModelConfiguration(schema: MicaboApp.schema, isStoredInMemoryOnly: true)
        )
        retained.append(container)
        return ModelContext(container)
    }

    private func photoStore() -> ChatPhotoStore {
        ChatPhotoStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("scan12-tests-\(UUID().uuidString)", isDirectory: true))
    }

    private func image() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
    }

    // MARK: - Les modes et leurs consignes

    func testEveryModeSpeaksEveryLanguage() {
        for locale in languages {
            for mode in ScanMode.allCases {
                for key in ["ios.scan12.mode.\(mode.rawValue)", "ios.scan12.hint.\(mode.rawValue)", "ios.scan12.label.\(mode.rawValue)", "ios.scan12.prompt.\(mode.rawValue)"] {
                    let text = L10n.t(key, locale: locale)
                    XCTAssertNotEqual(text, key, "\(locale.rawValue) : \(key) manque")
                    XCTAssertFalse(text.isEmpty, "\(locale.rawValue) : \(key)")
                }
            }
        }
    }

    func testEveryModeHasItsFramingAndThePickerShowsThemAll() {
        XCTAssertEqual(ScanMode.solve.framing, .question)
        XCTAssertEqual(ScanMode.equation.framing, .line)
        for mode in [ScanMode.explain, .vocabulary, .translate, .flashcards, .summary] {
            XCTAssertEqual(mode.framing, .page)
            XCTAssertTrue(mode.takesSeveralPages, "\(mode) : plusieurs pages à la suite")
        }
        XCTAssertFalse(ScanMode.solve.takesSeveralPages)
        XCTAssertEqual(Set(ScanMode.ordered), Set(ScanMode.allCases), "chaque mode a sa pastille")
        XCTAssertEqual(ScanMode.ordered.first, .solve, "le geste d'avant reste le premier")
        XCTAssertTrue(ScanMode.vocabulary.makesCards && ScanMode.flashcards.makesCards)
    }

    func testAConsigneSaysWhatToDoAndStaysWithinOneMessage() {
        for mode in ScanMode.allCases {
            let consigne = ScanPrompts.consigne(mode, typed: String(repeating: "x", count: 4_000), level: "Lycée", locale: .fr)
            XCTAssertLessThanOrEqual(consigne.count, MikaLimits.messageCharacters, "\(mode)")
            XCTAssertFalse(consigne.hasPrefix("ios."), "\(mode)")
        }
        let equation = ScanPrompts.consigne(.equation, level: nil, locale: .fr)
        XCTAssertTrue(equation.contains("LaTeX"), "une équation se rend en formules")
        let vocabulary = ScanPrompts.consigne(.vocabulary, level: nil, locale: .fr)
        XCTAssertTrue(vocabulary.contains("**mot**"), "le format que `ScanCardParser` lit")
        let typed = ScanPrompts.consigne(.explain, typed: "La photosynthèse", level: nil, locale: .fr)
        XCTAssertTrue(typed.hasSuffix("La photosynthèse"), "ce que l'élève a tapé suit la consigne")
        let leveled = ScanPrompts.consigne(.summary, level: "Collège", locale: .fr)
        XCTAssertTrue(leveled.contains("Collège"), "le niveau de l'élève suit")
    }

    /// La traduction demande la langue cible **dans la langue cible** : `mika-chat` répond dans
    /// la langue du dernier message.
    func testTheTranslationAsksInTheTargetLanguage() {
        let toGerman = ScanPrompts.consigne(.translate, target: .de, level: nil, locale: .fr)
        XCTAssertEqual(toGerman, L10n.t("ios.scan12.prompt.translate", locale: .de))
        XCTAssertTrue(toGerman.contains("Deutsche"))
        let toEnglish = ScanPrompts.consigne(.translate, target: .en, level: nil, locale: .fr)
        XCTAssertTrue(toEnglish.contains("English"))
        XCTAssertEqual(ScanPrompts.label(.translate, target: .en, locale: .fr), "Traduis en anglais")
        for target in ScanTranslation.targets {
            XCTAssertNotEqual(L10n.t("ios.scan12.prompt.translate", locale: target), "ios.scan12.prompt.translate")
        }
    }

    func testTheThreadTitleIsTheGestureAndTheStartOfThePage() {
        let title = ScanPrompts.threadTitle(.summary, firstText: "\n  \nLa photosynthèse\nLes plantes vertes…", locale: .fr)
        XCTAssertEqual(title, "Résume cette page · La photosynthèse")
        XCTAssertEqual(ScanPrompts.threadTitle(.explain, firstText: "", locale: .fr), "Explique-moi ce passage")
        let long = ScanPrompts.threadTitle(.explain, firstText: String(repeating: "mot ", count: 40), locale: .fr)
        XCTAssertLessThanOrEqual(long.count, ChatTitle.maxLength + 1)
    }

    // MARK: - La mémoire du mode

    func testTheModeIsRememberedFromOneTimeToTheNext() {
        let memory = ScanModeMemory(defaults: freshDefaults())
        XCTAssertEqual(memory.mode, .solve, "la première fois : résoudre, le geste d'avant")
        memory.mode = .translate
        XCTAssertEqual(ScanModeMemory(defaults: memory.defaults).mode, .translate)
        memory.defaults.set("inconnu", forKey: ScanModeMemory.Key.mode)
        XCTAssertEqual(memory.mode, .solve, "une valeur illisible ne casse rien")
    }

    func testTheTargetLanguageDefaultsToTheAppAndIsRemembered() {
        let memory = ScanModeMemory(defaults: freshDefaults())
        XCTAssertEqual(memory.target(appLocale: .de), .de)
        XCTAssertEqual(memory.target(appLocale: .es419), .es, "l'espagnol d'Amérique vise l'espagnol")
        XCTAssertEqual(memory.target(appLocale: .fi), .en, "une langue où Mika ne sait pas viser : l'anglais")
        memory.remember(target: .ar)
        XCTAssertEqual(memory.target(appLocale: .fr), .ar)
    }

    // MARK: - La lampe

    func testTheTorchButtonOnlyShowsWhenThereIsALampAndALiveView() {
        XCTAssertTrue(ScanTorch.isShown(hasTorch: true, cameraAvailable: true, live: true))
        XCTAssertFalse(ScanTorch.isShown(hasTorch: false, cameraAvailable: true, live: true), "pas de lampe : pas de bouton")
        XCTAssertFalse(ScanTorch.isShown(hasTorch: true, cameraAvailable: false, live: true), "caméra refusée")
        XCTAssertFalse(ScanTorch.isShown(hasTorch: true, cameraAvailable: true, live: false), "photo figée : la lampe ne sert plus")
        var state = ScanChromeState(hasTorch: false)
        XCTAssertFalse(state.showsTorch)
        state.hasTorch = true
        XCTAssertTrue(state.showsTorch)
    }

    // MARK: - Les pages

    func testAPageWithoutTextIsEmptyAndDoesNotLeave() {
        XCTAssertEqual(ScanPage.state(for: "  \n "), .empty)
        XCTAssertEqual(ScanPage.state(for: "abc"), .empty)
        XCTAssertEqual(ScanPage.state(for: "La photosynthèse est…"), .read("La photosynthèse est…"))
        var state = ScanChromeState(mode: .summary, pages: [ScanPage(image: image(), state: .reading)])
        XCTAssertFalse(state.canFinish, "on attend la lecture")
        state.pages = [ScanPage(image: image(), state: .read("texte lu"))]
        XCTAssertTrue(state.canFinish)
        state.pages = Array(repeating: ScanPage(image: image(), state: .read("x")), count: state.maxPages)
        XCTAssertTrue(state.isFull)
        XCTAssertEqual(ScanCapture.maxPages, ChatSession.maxPhotos, "une capture tient dans un message")
    }

    // MARK: - Les cartes d'un vocabulaire

    func testTheVocabularyBecomesCards() {
        let reply = """
        **Photosynthèse** : fabrication de matière par la plante grâce à la lumière. *Exemple : la feuille fait de la photosynthèse.*

        **chlorophylle :** pigment vert qui capte la lumière. *La chlorophylle colore les feuilles.*

        Une phrase sans mot en gras.

        **stomate** — petit orifice de la feuille.
        """
        let cards = ScanCardParser.vocabulary(from: reply)
        XCTAssertEqual(cards.map(\.front), ["Photosynthèse", "chlorophylle", "stomate"])
        XCTAssertEqual(cards.first?.back, "fabrication de matière par la plante grâce à la lumière.")
        XCTAssertEqual(cards[1].back, "pigment vert qui capte la lumière.")
        XCTAssertTrue(ScanCardParser.vocabulary(from: "Rien à relever ici.").isEmpty)
        let many = (1...30).map { "**mot\($0)** : sens numéro \($0)" }.joined(separator: "\n\n")
        XCTAssertEqual(ScanCardParser.vocabulary(from: many).count, ScanCardParser.maxCards)
    }

    // MARK: - Une capture, une question

    func testACaptureLeavesAsOneQuestionWithItsConsigne() async throws {
        let context = try context()
        let quota = MikaQuota(defaults: freshDefaults())
        let ai = ScanStubAI()
        let session = ChatSession(launch: ChatLaunch(origin: .scan), context: context, quota: quota, xp: nil, photos: photoStore())
        let capture = ScanCapture(mode: .translate, target: .en, pages: [
            ScanPage(image: image(), state: .read("Bonjour tout le monde")),
            ScanPage(image: image(), state: .read("Deuxième page")),
        ])
        session.queueScan(capture)
        XCTAssertEqual(session.pendingMode, .translate)
        XCTAssertEqual(session.pending.count, 2)
        await session.send(isPro: false, service: ai, context: context)

        XCTAssertEqual(ai.requests.count, 1, "deux pages, une seule question")
        let request = try XCTUnwrap(ai.requests.first)
        XCTAssertEqual(request.turns.last?.text, ScanPrompts.consigne(.translate, target: .en))
        XCTAssertTrue(request.attachment?.text.contains("Bonjour tout le monde") ?? false)
        XCTAssertTrue(request.attachment?.text.contains("Deuxième page") ?? false)
        XCTAssertNil(session.pendingMode, "le geste est parti avec les pages")
        XCTAssertEqual(session.bubbles.first?.scanMode, .translate)
        XCTAssertFalse(quota.hasFreeQuestion, "une capture = une question Mika")

        let thread = try XCTUnwrap(ChatStore.threads(in: context).first)
        XCTAssertEqual(thread.origin, .scan)
        XCTAssertTrue(thread.title.hasPrefix(ScanPrompts.label(.translate, target: .en)))
        let stored = ChatStore.messages(of: thread.id, in: context)
        XCTAssertEqual(stored.first?.scanMode, .translate)
        XCTAssertEqual(stored.first?.scanTarget, .en)

        // Relu de la base, la consigne se refait : la relance garde le geste.
        let reopened = ChatSession(launch: ChatLaunch(origin: .home, threadID: thread.id), context: context, quota: quota, xp: nil, photos: photoStore())
        XCTAssertEqual(reopened.request().turns.first?.text, ScanPrompts.consigne(.translate, target: .en))
    }

    func testABlockedCaptureKeepsItsPagesAndItsGesture() async throws {
        let context = try context()
        let quota = MikaQuota(defaults: freshDefaults())
        quota.noteAnswered()
        let ai = ScanStubAI()
        let session = ChatSession(launch: ChatLaunch(origin: .scan), context: context, quota: quota, xp: nil, photos: photoStore())
        session.queueScan(ScanCapture(mode: .summary, pages: [ScanPage(image: image(), state: .read("Une page de cours"))]))
        await session.send(isPro: false, service: ai, context: context)
        XCTAssertTrue(ai.requests.isEmpty)
        XCTAssertTrue(session.limitReached)
        XCTAssertEqual(session.paywall, .mika, "la porte de paywall existante")
        XCTAssertEqual(session.pendingMode, .summary, "après l'abonnement, la page part telle quelle")
        XCTAssertEqual(session.pending.count, 1)
    }

    func testTheVocabularyReplyOffersItsWordsAsCards() async throws {
        let context = try context()
        let ai = ScanStubAI(reply: "**osmose** : passage de l'eau à travers une membrane.\n\n**turgescence** : état d'une cellule gonflée d'eau.")
        let session = ChatSession(launch: ChatLaunch(origin: .scan), context: context, quota: MikaQuota(defaults: freshDefaults()), xp: nil, photos: photoStore())
        session.queueScan(ScanCapture(mode: .vocabulary, pages: [ScanPage(image: image(), state: .read("Une page de SVT"))]))
        await session.send(isPro: true, service: ai, context: context)
        let answer = try XCTUnwrap(session.bubbles.last)
        XCTAssertEqual(answer.cards.map(\.front), ["osmose", "turgescence"])
        XCTAssertNil(answer.card, "les mots remplacent la carte unique")

        let course = try CourseRepository.makeDeck(title: "SVT", in: context)
        XCTAssertEqual(session.addCards(of: answer.id, to: course, in: context), 2)
        XCTAssertEqual(session.addCards(of: answer.id, to: course, in: context), 0, "une seule fois")
        XCTAssertTrue(session.bubbles.last?.cardAdded ?? false)
    }

    func testFlashcardsComeFromTheCardsFunctionAndCostOneQuestion() async throws {
        let context = try context()
        let quota = MikaQuota(defaults: freshDefaults())
        let ai = ScanStubAI()
        let session = ChatSession(launch: ChatLaunch(origin: .scan), context: context, quota: quota, xp: nil, photos: photoStore())
        session.queueScan(ScanCapture(mode: .flashcards, pages: [ScanPage(image: image(), state: .read(String(repeating: "La cellule est l'unité du vivant. ", count: 4)))]))
        await session.send(isPro: false, service: ai, context: context)
        XCTAssertTrue(ai.requests.isEmpty, "pas de `mika-chat` pour des cartes")
        XCTAssertEqual(ai.flashcardRequests.count, 1)
        XCTAssertEqual(ai.flashcardRequests.first?.quota.total, ScanMode.cardCount)
        XCTAssertTrue(ai.flashcardRequests.first?.courseContext.contains("unité du vivant") ?? false)
        XCTAssertEqual(session.bubbles.last?.cards.count, 2)
        XCTAssertFalse(quota.hasFreeQuestion)
        let stored = ChatStore.messages(of: try XCTUnwrap(session.thread).id, in: context)
        XCTAssertEqual(stored.last?.cards.count, 2, "les cartes se gardent avec la réponse")
    }

    func testAPageScannedGivesALessonWithItsText() async throws {
        let context = try context()
        let session = ChatSession(launch: ChatLaunch(origin: .scan), context: context, quota: MikaQuota(defaults: freshDefaults()), xp: nil, photos: photoStore())
        let page = String(repeating: "Les volcans naissent aux frontières des plaques. ", count: 6)
        session.queueScan(ScanCapture(mode: .explain, pages: [ScanPage(image: image(), state: .read(page))]))
        await session.send(isPro: true, service: ScanStubAI(), context: context)
        let seed = try XCTUnwrap(session.lessonSeed)
        XCTAssertEqual(seed.text, page)
        XCTAssertTrue(seed.topic.hasPrefix("Les volcans"))
    }

    // MARK: - L'historique, par jour

    func testTheHistoryIsSortedTodayYesterdayWeekOlder() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(ChatHistorySection.of(now.addingTimeInterval(-60), now: now, calendar: calendar), .today)
        XCTAssertEqual(ChatHistorySection.of(now.addingTimeInterval(-86_400), now: now, calendar: calendar), .yesterday)
        XCTAssertEqual(ChatHistorySection.of(now.addingTimeInterval(-5 * 86_400), now: now, calendar: calendar), .week)
        XCTAssertEqual(ChatHistorySection.of(now.addingTimeInterval(-90 * 86_400), now: now, calendar: calendar), .older)
        XCTAssertEqual(ChatHistorySection.of(now.addingTimeInterval(-400 * 86_400), now: now, calendar: calendar), .older, "un an : toujours « plus ancien », pas une section par mois")
        for locale in languages {
            for section in [ChatHistorySection.today, .yesterday, .week, .older] {
                XCTAssertFalse(section.title(locale: locale).hasPrefix("ios."), "\(locale.rawValue)")
            }
        }
    }

    func testEachOriginHasItsFamilyIcon() {
        XCTAssertEqual(ChatOrigin.home.family, .chat)
        XCTAssertEqual(ChatOrigin.camera.family, .chat)
        XCTAssertEqual(ChatOrigin.scan.family, .scan)
        XCTAssertEqual(ChatOrigin.lesson.family, .lesson)
        XCTAssertEqual(ChatOrigin.quiz.family, .lesson)
        XCTAssertEqual(Set([ChatFamily.chat, .scan, .lesson].map(\.symbol)).count, 3, "trois icônes distinctes")
    }

    func testSearchFindsATitleALessonOrAPreviewWithoutAccents() throws {
        let context = try context()
        let thread = ChatStore.createThread(origin: .lesson, courseTitle: "Les équations", in: context)
        ChatStore.append(.user, text: "Comment résoudre ?", to: thread, in: context)
        let other = ChatStore.createThread(origin: .home, in: context)
        ChatStore.append(.user, text: "La Révolution", to: other, in: context)
        let all = ChatStore.threads(in: context)
        XCTAssertEqual(ChatStore.search(all, query: "equations").count, 1)
        XCTAssertEqual(ChatStore.search(all, query: "revolution").count, 1)
        XCTAssertEqual(ChatStore.search(all, query: "").count, 2)
    }

    // MARK: - Le tiroir

    func testTheDrawerFollowsTheFingerAndSettles() {
        let width = SideDrawer<EmptyView, EmptyView>.width(for: 390)
        XCTAssertEqual(width, 327.6, accuracy: 0.1)
        XCTAssertEqual(SideDrawer<EmptyView, EmptyView>.width(for: 1024), 340, "pas plus large qu'une colonne")
        XCTAssertEqual(SideDrawer<EmptyView, EmptyView>.progress(isOpen: false, drag: nil, width: width), 0)
        XCTAssertEqual(SideDrawer<EmptyView, EmptyView>.progress(isOpen: false, drag: width / 2, width: width), 0.5, accuracy: 0.001)
        XCTAssertEqual(SideDrawer<EmptyView, EmptyView>.progress(isOpen: true, drag: -2 * width, width: width), 0, "jamais au-delà")
        XCTAssertTrue(SideDrawer<EmptyView, EmptyView>.settles(open: 0.6, velocity: 0))
        XCTAssertFalse(SideDrawer<EmptyView, EmptyView>.settles(open: 0.4, velocity: 0))
        XCTAssertTrue(SideDrawer<EmptyView, EmptyView>.settles(open: 0.2, velocity: 900), "un geste vif ouvre")
        XCTAssertFalse(SideDrawer<EmptyView, EmptyView>.settles(open: 0.8, velocity: -900), "un geste vif referme")
    }

    // MARK: - La feuille Outils

    func testTheToolsSheetHasThreeGroupsAndOnlyWhatWorks() {
        let fresh = ToolGroup.groups(context: .home, availability: ToolsAvailability())
        XCTAssertEqual(fresh.map(\.kind), [.sources, .understand, .practice])
        let practice = fresh.first { $0.kind == .practice }?.items ?? []
        XCTAssertFalse(practice.contains(.quiz), "pas de quiz sans leçon")
        XCTAssertFalse(practice.contains(.mock), "pas d'examen blanc sans leçons")
        XCTAssertTrue(practice.contains(.focus), "la séance de concentration est toujours là")
        XCTAssertEqual(fresh.first { $0.kind == .understand }?.items, [.explain, .summary, .translate, .solve])

        let active = ToolGroup.groups(context: .home, availability: ToolsAvailability(hasLesson: true, hasLessons: true))
        XCTAssertTrue(active.flatMap(\.items).contains(.quiz))
        XCTAssertTrue(active.flatMap(\.items).contains(.mock))

        let full = ToolGroup.groups(context: .home, availability: ToolsAvailability(canImport: false))
        XCTAssertEqual(full.first?.items, [.camera], "la barre est pleine : les imports se cachent, la caméra reste")

        let chat = ToolGroup.groups(context: .chat, availability: ToolsAvailability())
        XCTAssertEqual(chat.first?.items, [.camera, .photos, .files])
        XCTAssertFalse(chat.flatMap(\.items).contains(.plan), "le plan de révision vit dans le Calendrier, pas dans une conversation")
        XCTAssertLessThanOrEqual(chat.count, 3)
    }

    func testEveryToolIsNamedInEveryLanguage() {
        for locale in languages {
            for item in ToolItem.allCases {
                XCTAssertFalse(item.title(locale: locale).hasPrefix("ios."), "\(locale.rawValue) \(item)")
            }
            for kind in [ToolGroup.Kind.sources, .practice, .understand] {
                XCTAssertFalse(ToolGroup(kind: kind, items: []).title(locale: locale).hasPrefix("ios."))
            }
        }
    }

    func testTheNewEventsCarryFixedNamesOnly() {
        for event in [AnalyticsEvent.scanOpened, .scanModeChosen, .scanCaptured, .scanUnreadable, .toolsOpened, .toolPicked, .drawerOpened] {
            XCTAssertTrue(["scan_", "tool", "drawer_"].contains { event.rawValue.hasPrefix($0) })
        }
        XCTAssertEqual(Set(ScanMode.allCases.map(\.analyticsName)).count, ScanMode.allCases.count)
    }
}

// MARK: - La doublure

private final class ScanStubAI: AIService {
    var requests: [MikaChatRequest] = []
    var flashcardRequests: [FlashcardGenerationRequest] = []
    var reply = "Voici."

    init(reply: String = "Voici.") {
        self.reply = reply
    }

    func generateCourse(_ request: CourseGenerationRequest) async throws -> GeneratedCourse {
        throw AIServiceError.notConfigured
    }

    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard] {
        flashcardRequests.append(request)
        return [GeneratedFlashcard(front: "Qu'est-ce qu'une cellule ?", back: "L'unité du vivant."), GeneratedFlashcard(front: "Rôle du noyau ?", back: "Porter l'ADN.")]
    }

    func explain(_ request: SelectionExplanationRequest) async throws -> SelectionExplanation {
        throw AIServiceError.notConfigured
    }

    func chat(_ request: MikaChatRequest) async throws -> MikaChatReply {
        requests.append(request)
        return MikaChatReply(reply: reply, card: GeneratedFlashcard(front: "Q", back: "R"))
    }
}
