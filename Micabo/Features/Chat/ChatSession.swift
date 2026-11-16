import Foundation
import Observation
import SwiftData
import UIKit

// MARK: - Ce qui ouvre une conversation

/// **Comment une conversation s'ouvre** : d'où (pour l'icône et les statistiques), sur quel
/// fil (une reprise), liée à quelle leçon ou à quel exercice, avec quoi dans le champ, et si
/// l'appareil photo s'ouvre tout de suite.
struct ChatLaunch: Identifiable, Hashable {
    var id = UUID()
    var origin: ChatOrigin = .home
    /// Un fil à reprendre (l'historique) ; `nil` : une nouvelle conversation, créée au premier envoi.
    var threadID: UUID?
    var courseID: UUID?
    var exerciseID: UUID?
    /// Ce qui se pose dans le champ, sans partir (« Explique-moi cette carte : … »).
    var prefill: String?
    /// Ce qui part tout de suite (la question tapée sur la Home).
    var autoSend: String?
    /// L'appareil photo en rafale s'ouvre dès l'arrivée.
    var opensCamera = false
    /// Lot 12 — une capture de la caméra à modes, envoyée dès l'arrivée.
    var scan: ScanPayload?

    /// La conversation d'une leçon : la dernière reprise, sinon une nouvelle.
    static func lesson(_ courseID: UUID, origin: ChatOrigin = .lesson, prefill: String? = nil) -> ChatLaunch {
        ChatLaunch(origin: origin, courseID: courseID, prefill: prefill)
    }
}

/// Un message tel que l'écran le dessine.
struct ChatBubble: Identifiable, Equatable {
    var id: UUID
    var role: MikaTurn.Role
    var text: String
    var photoNames: [String] = []
    var card: GeneratedFlashcard?
    var cardAdded = false
    var exerciseID: UUID?
    /// Lot 12 — le geste de la caméra (la bulle de l'élève le nomme), et sa langue cible.
    var scanMode: ScanMode?
    var scanTarget: UiLocale?
    /// Lot 12 — les cartes d'un vocabulaire ou de cartes mémoire, à ranger d'un geste.
    var cards: [GeneratedFlashcard] = []

    init(id: UUID = UUID(), role: MikaTurn.Role, text: String, photoNames: [String] = [], card: GeneratedFlashcard? = nil, cardAdded: Bool = false, exerciseID: UUID? = nil, scanMode: ScanMode? = nil, scanTarget: UiLocale? = nil, cards: [GeneratedFlashcard] = []) {
        self.id = id
        self.role = role
        self.text = text
        self.photoNames = photoNames
        self.card = card
        self.cardAdded = cardAdded
        self.exerciseID = exerciseID
        self.scanMode = scanMode
        self.scanTarget = scanTarget
        self.cards = cards
    }

    init(_ message: ChatMessage) {
        self.init(id: message.id, role: message.role, text: message.text, photoNames: message.photoNames, card: message.card, cardAdded: message.cardAdded, exerciseID: message.exerciseID, scanMode: message.scanMode, scanTarget: message.scanTarget, cards: message.cards)
    }
}

/// Une photo prise ou choisie, pas encore envoyée : sa vignette, et où en est sa lecture.
struct ChatPendingPhoto: Identifiable, Equatable {
    enum State: Equatable {
        case reading
        case read(String)
        /// L'appareil n'y a rien lu : elle part quand même si la question est tapée.
        case unreadable
    }

    var id = UUID()
    var image: UIImage
    var state: State = .reading

    var text: String {
        if case .read(let text) = state { return text }
        return ""
    }
}

/// **« En faire une leçon »**, depuis une conversation : le sujet, un titre, et le texte des
/// pages passées à la caméra quand il y en a.
struct ChatLessonSeed: Equatable {
    var topic: String
    var title: String
    var text: String?
}

// MARK: - La conversation

/// **La conversation avec Mika** (lot 11) : une question tapée, une ou plusieurs photos, des
/// relances, gardée dans l'historique.
///
/// - **Les photos sont lues sur le téléphone** (Vision) dès qu'elles arrivent ; leur texte part
///   dans le document joint de `mika-chat`, ce que le serveur déployé accepte. Les images ne
///   voyagent pas.
/// - **Un message = une question Mika**, photos comprises : la porte est `MikaQuota`, la même
///   que partout (une question offerte, puis Pro ; un plafond par jour pour un abonné), et la
///   question ne se compte qu'une fois la réponse arrivée.
/// - Le fil n'existe dans l'historique qu'au premier envoi : ouvrir le chat et repartir ne
///   laisse pas de conversation vide.
@Observable
@MainActor
final class ChatSession {
    static let maxPhotos = 6

    private(set) var thread: ChatThread? = nil
    private(set) var bubbles: [ChatBubble] = []
    var draft = ""
    private(set) var pending: [ChatPendingPhoto] = []
    private(set) var thinking = false
    private(set) var failure: String? = nil
    /// Le plafond du jour d'un abonné vient de refuser.
    private(set) var capReached = false
    /// La question offerte est passée : la limite se dit dans le fil, avec la porte du paywall.
    private(set) var limitReached = false
    var paywall: PaywallTrigger? = nil
    /// Lot 12 — le geste de la caméra qui attend son envoi avec les photos en attente
    /// (« Traduire en anglais ») : il part avec elles, en une question.
    private(set) var pendingMode: ScanMode? = nil
    private(set) var pendingTarget: UiLocale? = nil

    let origin: ChatOrigin
    private(set) var courseID: UUID? = nil
    private(set) var courseTitle: String? = nil
    private var courseText: String? = nil
    private var courseLanguage: ContentLanguage? = nil
    private(set) var exerciseID: UUID? = nil
    private var exerciseDocument: String? = nil

    let quota: MikaQuota
    private let xp: XPStore?
    private let photos: ChatPhotoStore
    private let recognize: (UIImage) async -> String

    init(
        launch: ChatLaunch,
        context: ModelContext?,
        quota: MikaQuota = MikaQuota(),
        xp: XPStore? = .shared,
        photos: ChatPhotoStore = .shared,
        recognize: @escaping (UIImage) async -> String = ChatSession.readOnDevice
    ) {
        self.origin = launch.origin
        self.quota = quota
        self.xp = xp
        self.photos = photos
        self.recognize = recognize
        self.courseID = launch.courseID
        self.exerciseID = launch.exerciseID
        if let prefill = launch.prefill { draft = prefill }
        guard let context else { return }
        if let id = launch.threadID, let found = ChatStore.thread(id, in: context) {
            adopt(found, in: context)
        } else if launch.origin == .lesson, let courseID = launch.courseID, let found = ChatStore.latestThread(forCourse: courseID, in: context) {
            adopt(found, in: context)
        } else if let exerciseID = launch.exerciseID, let found = ChatStore.thread(forExercise: exerciseID, in: context) {
            adopt(found, in: context)
        }
        loadContext(in: context)
    }

    /// Une conversation dessinée telle quelle (les rendus) : sans base ni réseau.
    init(preview bubbles: [ChatBubble], title: String? = nil, courseTitle: String? = nil, pending: [ChatPendingPhoto] = [], pendingMode: ScanMode? = nil, draft: String = "", thinking: Bool = false, failure: String? = nil, limitReached: Bool = false, capReached: Bool = false) {
        self.origin = .home
        self.quota = MikaQuota()
        self.xp = nil
        self.photos = .shared
        self.recognize = { _ in "" }
        self.bubbles = bubbles
        self.courseTitle = courseTitle
        self.courseID = courseTitle == nil ? nil : UUID()
        self.pending = pending
        self.pendingMode = pendingMode
        self.draft = draft
        self.thinking = thinking
        self.failure = failure
        self.limitReached = limitReached
        self.capReached = capReached
        self.previewTitle = title
    }

    private var previewTitle: String? = nil

    // MARK: Ce que l'écran lit

    var title: String {
        if let thread, !thread.title.isEmpty { return thread.title }
        return previewTitle ?? "Mika"
    }

    var isEmpty: Bool { bubbles.isEmpty }
    var isReading: Bool { pending.contains { $0.state == .reading } }
    var hasRoomForPhotos: Bool { pending.count < Self.maxPhotos }
    var canSend: Bool {
        guard !thinking, !isReading else { return false }
        return !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pending.isEmpty
    }

    /// Le geste en attente, tel que la barre de saisie le montre.
    var pendingLabel: String? {
        pendingMode.map { ScanPrompts.label($0, target: pendingTarget) }
    }

    var canRetry: Bool { failure != nil && bubbles.last?.role == .user && !thinking }

    /// « En faire une leçon » : hors leçon, et quand il y a une question à en tirer.
    var lessonTopic: String? {
        guard courseID == nil, bubbles.contains(where: { $0.role == .mika }) else { return nil }
        if let pageText = scannedText, !pageText.isEmpty {
            // Une page passée à la caméra : son début dit le sujet mieux que « Résumer ».
            return String(pageText.prefix(300))
        }
        let question = bubbles.first(where: { $0.role == .user && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.text
        let topic = (question ?? thread?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return topic.isEmpty ? nil : String(topic.prefix(300))
    }

    // MARK: Les photos

    /// Des photos arrivent (l'appareil, la photothèque) : elles se lisent tout de suite, une à
    /// une. Au-delà de six, les suivantes sont laissées de côté.
    func add(photos images: [UIImage]) {
        for image in images where pending.count < Self.maxPhotos {
            let photo = ChatPendingPhoto(image: image)
            pending.append(photo)
            let read = recognize
            Task { [weak self] in
                let text = await read(image)
                self?.finishReading(photo.id, text: text)
            }
        }
    }

    func finishReading(_ id: UUID, text: String) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let clean = TextSanitizer.normalizeExtractedText(text).trimmingCharacters(in: .whitespacesAndNewlines)
        pending[index].state = clean.count >= 4 ? .read(String(clean.prefix(MikaLimits.attachmentCharacters))) : .unreadable
    }

    func remove(photo id: UUID) {
        pending.removeAll { $0.id == id }
        if pending.isEmpty, draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { clearPendingMode() }
    }

    func clearPendingMode() {
        pendingMode = nil
        pendingTarget = nil
    }

    /// Le texte lu sur les pages passées à la caméra dans cette conversation, à la suite.
    var scannedText: String? {
        let texts = bubbles.filter { $0.role == .user && $0.scanMode != nil }.flatMap { storedTexts[$0.id] ?? [] }.filter { !$0.isEmpty }
        return texts.isEmpty ? nil : texts.joined(separator: "\n\n")
    }

    /// **« En faire une leçon »** : le sujet, et le texte des pages quand il y en a — la Home
    /// en fait un support de leçon plutôt qu'un sujet de trois cents caractères.
    var lessonSeed: ChatLessonSeed? {
        guard let topic = lessonTopic else { return nil }
        return ChatLessonSeed(topic: topic, title: thread?.title ?? topic, text: scannedText)
    }

    // MARK: La caméra à modes

    /// **Une capture de la caméra arrive** (lot 12) : ses pages, déjà lues sur l'appareil,
    /// deviennent les photos en attente, avec leur geste ; le texte tapé à la place d'une photo
    /// va dans le champ. Puis tout part, en une question.
    func queueScan(_ capture: ScanCapture) {
        pending = capture.pages.prefix(Self.maxPhotos).map { page in
            ChatPendingPhoto(image: page.image, state: page.text.isEmpty ? .unreadable : .read(page.text))
        }
        pendingMode = capture.mode
        pendingTarget = capture.mode == .translate ? capture.target : nil
        if !capture.typed.isEmpty { draft = String(capture.typed.prefix(MikaLimits.messageCharacters)) }
    }

    // MARK: Envoyer

    /// Envoie la question tapée et les photos en attente, si la porte est ouverte.
    func send(_ text: String? = nil, isPro: Bool, service: any AIService, context: ModelContext?) async {
        let message = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        let photosToSend = text == nil ? pending : []
        guard !thinking, !isReading, !message.isEmpty || !photosToSend.isEmpty else { return }
        failure = nil
        capReached = false
        switch quota.gate(isPro: isPro) {
        case .allowed:
            limitReached = false
        case .paywall:
            limitReached = true
            paywall = .mika
            Analytics.track(.mikaBlocked, ["reason": .text("paywall")])
            return
        case .dailyCapReached:
            capReached = true
            Haptics.warning()
            Analytics.track(.mikaBlocked, ["reason": .text("cap")])
            return
        }

        if text == nil {
            draft = ""
            pending = []
        }
        let mode = text == nil ? pendingMode : nil
        let target = text == nil ? pendingTarget : nil
        if text == nil { clearPendingMode() }
        let names = photosToSend.compactMap { photos.save($0.image) }
        let texts = photosToSend.map(\.text)
        let clipped = String(message.prefix(MikaLimits.messageCharacters))
        if let context {
            let thread = self.thread ?? ChatStore.createThread(origin: mode != nil && bubbles.isEmpty ? .scan : origin, courseID: courseID, courseTitle: courseTitle, exerciseID: exerciseID, in: context)
            self.thread = thread
            let stored = ChatStore.append(.user, text: clipped, photoNames: names, photoTexts: names.count == texts.count ? texts : [], scanMode: mode, scanTarget: target, to: thread, in: context)
            bubbles.append(ChatBubble(stored))
            storedTexts[stored.id] = texts
        } else {
            let bubble = ChatBubble(role: .user, text: clipped, photoNames: names, scanMode: mode, scanTarget: target)
            bubbles.append(bubble)
            storedTexts[bubble.id] = texts
        }
        Analytics.track(.chatSent, [
            "origin": .text(origin.rawValue),
            "photos": .number(Double(photosToSend.count)),
            "linked": .flag(courseID != nil || exerciseID != nil),
            "mode": .text(mode?.analyticsName ?? "none"),
        ])
        await ask(isPro: isPro, service: service, context: context)
    }

    func retry(isPro: Bool, service: any AIService, context: ModelContext?) async {
        guard canRetry else { return }
        failure = nil
        await ask(isPro: isPro, service: service, context: context)
    }

    /// Le texte lu sur les photos de chaque message de l'élève, gardé pour les relances.
    private var storedTexts: [UUID: [String]] = [:]

    private func ask(isPro: Bool, service: any AIService, context: ModelContext?) async {
        thinking = true
        defer { thinking = false }
        do {
            let asked = bubbles.last(where: { $0.role == .user })
            let text: String
            var card: GeneratedFlashcard? = nil
            var cards: [GeneratedFlashcard] = []
            if asked?.scanMode == .flashcards, let asked {
                // Les cartes mémoire : `generate-flashcards`, la fonction des cartes d'une leçon.
                cards = try await service.generateFlashcards(flashcardRequest(for: asked))
                    .filter { !$0.front.isEmpty && !$0.back.isEmpty }
                guard !cards.isEmpty else { throw AIServiceError.invalidResponse }
                text = L10n.t("ios.scan12.cards.reply", locale: .resolved(), vars: ["count": "\(cards.count)"])
            } else {
                let reply = try await service.chat(request())
                guard reply.isUsable else { throw AIServiceError.invalidResponse }
                text = reply.reply
                if asked?.scanMode == .vocabulary {
                    cards = ScanCardParser.vocabulary(from: reply.reply)
                }
                if cards.isEmpty { card = reply.card }
            }
            if let context, let thread {
                let stored = ChatStore.append(.mika, text: text, card: card, cards: cards, to: thread, in: context)
                bubbles.append(ChatBubble(stored))
            } else {
                bubbles.append(ChatBubble(role: .mika, text: text, card: card, cards: cards))
            }
            quota.noteAnswered()
            xp?.award(.mikaAnswer)
            Haptics.tick()
            Analytics.track(.mikaAsked, ["pro": .flag(isPro), "attached": .flag(courseID != nil || hasPhotos)])
        } catch {
            failure = SolverSession.message(for: error)
        }
    }

    private var hasPhotos: Bool { bubbles.contains { !$0.photoNames.isEmpty } }

    /// La demande de cartes : le texte des pages (et ce que l'élève a tapé), huit cartes simples
    /// dans la langue de l'app.
    func flashcardRequest(for bubble: ChatBubble) -> FlashcardGenerationRequest {
        let pages = (storedTexts[bubble.id] ?? []).filter { !$0.isEmpty }
        let context = (pages + [bubble.text]).filter { !$0.isEmpty }.joined(separator: "\n\n")
        return FlashcardGenerationRequest(
            courseTitle: thread?.title ?? ScanPrompts.label(.flashcards),
            courseContext: String(context.prefix(MikaLimits.attachmentCharacters)),
            existingFronts: [],
            quota: QuestionQuota(basic: ScanMode.cardCount, cloze: 0, choice: 0),
            language: UiLocale.resolved().contentLanguage
        )
    }

    /// **La demande** : les huit derniers tours (une question faite de photos seules dit « Explique-
    /// moi ce qu'il y a sur la photo »), et le document joint — le texte des photos de ces tours,
    /// puis la leçon ou l'exercice.
    func request() -> MikaChatRequest {
        let recent = Array(bubbles.suffix(MikaLimits.turns))
        let turns = recent.map { bubble -> MikaTurn in
            var text = bubble.text
            if bubble.role == .user, let mode = bubble.scanMode {
                // Un geste de la caméra : sa consigne, refaite à chaque fois, et ce qui a été tapé.
                text = ScanPrompts.consigne(mode, target: bubble.scanTarget, typed: bubble.text)
            } else if bubble.role == .user, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = L10n.t(bubble.photoNames.count > 1 ? "ios.chat11.ask.photos" : "ios.chat11.ask.photo", locale: .resolved())
            }
            return MikaTurn(role: bubble.role, text: String(text.prefix(MikaLimits.messageCharacters)))
        }
        var numbered: [ChatDocument.Photo] = []
        var number = 0
        for bubble in bubbles where bubble.role == .user {
            let texts = storedTexts[bubble.id] ?? []
            for index in bubble.photoNames.indices.isEmpty ? texts.indices : bubble.photoNames.indices {
                number += 1
                guard recent.contains(where: { $0.id == bubble.id }) else { continue }
                numbered.append(ChatDocument.Photo(number: number, text: index < texts.count ? texts[index] : ""))
            }
        }
        let attachment = ChatDocument.payload(
            photos: numbered,
            contextTitle: exerciseDocument != nil ? SolverPrompts.exerciseTitle : courseTitle,
            contextText: exerciseDocument ?? courseText
        )
        // Le geste de la caméra, quand le dernier message en vient : le serveur de demain s'en
        // sert, celui d'aujourd'hui l'ignore.
        let mode = recent.last(where: { $0.role == .user })?.scanMode?.rawValue
        return MikaChatRequest(turns: turns, attachment: attachment, language: language, level: OnboardingPreferences.educationStage?.level, mode: mode)
    }

    /// La langue de la leçon liée, sinon celle de l'interface.
    private var language: ContentLanguage {
        courseLanguage ?? SolverSession.language
    }

    // MARK: Le fil

    /// Reprend une conversation de l'historique.
    func open(_ id: UUID, in context: ModelContext) {
        guard let found = ChatStore.thread(id, in: context) else { return }
        reset()
        adopt(found, in: context)
        loadContext(in: context)
    }

    /// Une nouvelle conversation, sur la même leçon s'il y en a une.
    func startOver() {
        reset()
        thread = nil
        bubbles = []
    }

    private func reset() {
        draft = ""
        pending = []
        clearPendingMode()
        failure = nil
        capReached = false
        limitReached = false
        storedTexts = [:]
    }

    private func adopt(_ found: ChatThread, in context: ModelContext) {
        thread = found
        courseID = found.courseID ?? courseID
        courseTitle = found.courseTitle ?? courseTitle
        exerciseID = found.exerciseID ?? exerciseID
        let messages = ChatStore.messages(of: found.id, in: context)
        bubbles = messages.map(ChatBubble.init)
        for message in messages where !message.photoTexts.isEmpty {
            storedTexts[message.id] = message.photoTexts
        }
    }

    /// La leçon ou l'exercice liés, relus dans la base.
    private func loadContext(in context: ModelContext) {
        if let courseID {
            let target = courseID
            var descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            if let course = try? context.fetch(descriptor).first {
                let attachment = LessonMikaView.attachment(for: course)
                courseTitle = course.title
                courseText = attachment.text
                courseLanguage = course.language
            }
        }
        if let exerciseID {
            let target = exerciseID
            var descriptor = FetchDescriptor<SolvedExercise>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            if let exercise = try? context.fetch(descriptor).first {
                exerciseDocument = SolverPrompts.document(statement: exercise.statement, solution: exercise.solution)
            }
        }
    }

    // MARK: Les passerelles

    /// La carte proposée par Mika rejoint une leçon : celle de la conversation, ou celle choisie.
    @discardableResult
    func addCard(of bubbleID: UUID, to course: Course, in context: ModelContext) -> Bool {
        guard let index = bubbles.firstIndex(where: { $0.id == bubbleID }),
              !bubbles[index].cardAdded,
              let card = bubbles[index].card,
              let inserted = try? CourseRepository.addFlashcards([card], to: course, in: context),
              !inserted.isEmpty
        else { return false }
        bubbles[index].cardAdded = true
        let target = bubbleID
        var descriptor = FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        if let message = try? context.fetch(descriptor).first {
            message.cardAdded = true
            try? context.save()
        }
        Haptics.success()
        Analytics.track(.mikaCardAdded)
        Analytics.track(.chatGateway, ["kind": .text("card")])
        return true
    }

    /// Les cartes d'un vocabulaire ou de cartes mémoire rejoignent une leçon, toutes d'un coup.
    @discardableResult
    func addCards(of bubbleID: UUID, to course: Course, in context: ModelContext) -> Int {
        guard let index = bubbles.firstIndex(where: { $0.id == bubbleID }),
              !bubbles[index].cardAdded,
              !bubbles[index].cards.isEmpty,
              let inserted = try? CourseRepository.addFlashcards(bubbles[index].cards, to: course, in: context),
              !inserted.isEmpty
        else { return 0 }
        bubbles[index].cardAdded = true
        let target = bubbleID
        var descriptor = FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        if let message = try? context.fetch(descriptor).first {
            message.cardAdded = true
            try? context.save()
        }
        Haptics.success()
        Analytics.track(.chatGateway, ["kind": .text("cards"), "count": .number(Double(inserted.count))])
        return inserted.count
    }

    // MARK: La lecture

    /// Le texte d'une photo, lu sur l'appareil dans la langue de l'app d'abord.
    nonisolated static func readOnDevice(_ image: UIImage) async -> String {
        let preferred = await MainActor.run { [UiLocale.resolved().bcp47] }
        return await OnDeviceOCR.recognizeExercise(in: SolverImage.normalized(image, maxDimension: 2400), preferred: preferred)
    }
}
