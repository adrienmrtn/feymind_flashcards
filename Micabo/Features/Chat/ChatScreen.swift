import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - L'écran

/// **Le chat avec Mika** (lot 11) : une question, des photos, une réponse simple, des relances ;
/// l'historique en un geste (l'horloge en haut), une nouvelle conversation (le crayon).
///
/// Tout y renvoie : la barre de la Home, son appareil photo, le scanner, la tuile Mika d'une
/// leçon, « Demander à Mika » depuis une carte ou une question de quiz. Lié à une leçon, Mika a
/// ses notes sous les yeux et sa carte rejoint la leçon.
///
/// La mise en page : la barre du haut sous l'encoche, le fil qui défile, la barre de saisie
/// posée dans la zone sûre du bas — elle monte avec le clavier et reste au-dessus de lui.
struct ChatScreen: View {
    let launch: ChatLaunch
    /// « En faire une leçon » : la Home reprend le sujet (et le texte des pages lues) et lance
    /// la création qu'elle connaît. `nil` là où la Home n'est pas derrière (une leçon, la séance).
    var onMakeLesson: ((ChatLessonSeed) -> Void)?
    /// Fermer : `dismiss` par défaut ; une pile de navigation passe son retour.
    var onClose: (() -> Void)?
    /// Le symbole du bouton de sortie : la croix d'une feuille, la flèche d'une pile.
    var closeSymbol = "xmark"

    init(launch: ChatLaunch, onMakeLesson: ((ChatLessonSeed) -> Void)? = nil, onClose: (() -> Void)? = nil, closeSymbol: String = "xmark") {
        self.launch = launch
        self.onMakeLesson = onMakeLesson
        self.onClose = onClose
        self.closeSymbol = closeSymbol
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(ProAccess.self) private var pro: ProAccess?

    @State private var session: ChatSession?
    @State private var showsCamera = false
    @State private var showsHistory = false
    @State private var choosingLessonFor: UUID?
    /// Lot 12 — la feuille Outils du « + », et ce qu'elle a choisi (ouvert une fois refermée).
    @State private var showsTools = false
    @State private var pickedTool: ToolItem?
    @State private var scanMode: ChatScanMode?
    @State private var showsPicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showsFiles = false
    @State private var focusPlan: FocusPlan?
    @State private var quizCourse: Course?
    @FocusState private var focused: Bool

    private var isPro: Bool { pro?.isPro ?? false }

    var body: some View {
        Group {
            if let session {
                content(session)
            } else {
                V3Color.bg.ignoresSafeArea()
            }
        }
        .onAppear(perform: prepare)
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Le compilateur type mal d'un seul tenant la conversation et toutes ses présentations :
    /// celles du lot 12 (les outils) se posent dans leur propre fonction.
    private func content(_ session: ChatSession) -> some View {
        toolPresentations(conversation(session), session: session)
    }

    @ViewBuilder
    private func conversation(_ session: ChatSession) -> some View {
        @Bindable var session = session
        ChatConversationView(
            session: session,
            focused: $focused,
            showsMakeLesson: onMakeLesson != nil,
            actions: actions(session)
        )
        .fullScreenCover(isPresented: $showsCamera) {
            ChatCameraView(room: ChatSession.maxPhotos - session.pending.count) { images in
                session.add(photos: images)
            }
        }
        .sheet(isPresented: $showsHistory) {
            NavigationStack {
                ChatHistoryView(
                    currentID: session.thread?.id,
                    onOpen: { id in
                        showsHistory = false
                        session.open(id, in: modelContext)
                        Analytics.track(.chatOpened, ["origin": .text(session.thread?.origin.rawValue ?? "home"), "resumed": .flag(true)])
                    },
                    onNew: {
                        showsHistory = false
                        session.startOver()
                    },
                    onClose: { showsHistory = false }
                )
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: lessonChoice) { choice in
            ChatLessonPicker(newLessonTitle: session.title) { course in
                if session.bubbles.first(where: { $0.id == choice.id })?.cards.isEmpty == false {
                    session.addCards(of: choice.id, to: course, in: modelContext)
                } else {
                    session.addCard(of: choice.id, to: course, in: modelContext)
                }
                choosingLessonFor = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .micaboPaywall($session.paywall)
    }

    /// **Ce que le « + » ouvre** (lot 12) : la feuille Outils, puis la caméra à modes, la
    /// photothèque, les fichiers, une séance ou un quiz.
    private func toolPresentations<Base: View>(_ base: Base, session: ChatSession) -> some View {
        base
        .sheet(isPresented: $showsTools, onDismiss: { openTool(session) }) {
            ToolsSheet(context: .chat, availability: ToolsAvailability(hasLesson: session.courseID != nil, hasLessons: false, canImport: session.hasRoomForPhotos)) { item in
                pickedTool = item
                showsTools = false
            }
        }
        .fullScreenCover(item: $scanMode) { choice in
            ScanCaptureView(context: .chat, initialMode: choice.mode, onCapture: { capture in
                scanMode = nil
                session.queueScan(capture)
                send(session, nil)
            }, onClose: { scanMode = nil })
        }
        .fullScreenCover(item: $focusPlan) { plan in
            FocusTimerView(plan: plan)
        }
        .fullScreenCover(item: $quizCourse) { course in
            QuickQuizSheet(course: course)
        }
        .photosPicker(isPresented: $showsPicker, selection: $pickerItems, maxSelectionCount: max(1, ChatSession.maxPhotos - session.pending.count), selectionBehavior: .ordered, matching: .images)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            pickerItems = []
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                session.add(photos: images)
            }
        }
        .fileImporter(isPresented: $showsFiles, allowedContentTypes: [.image, .pdf], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            let room = ChatSession.maxPhotos - session.pending.count
            session.add(photos: ScanFileLoader.load(urls, limit: max(0, room)).map(\.image))
        }
    }

    /// **Une entrée de la feuille Outils**, ouverte une fois la feuille refermée : la caméra en
    /// rafale, la photothèque, les fichiers, un geste de la caméra à modes, une séance, un quiz.
    private func openTool(_ session: ChatSession) {
        guard let item = pickedTool else { return }
        pickedTool = nil
        if let mode = item.scanMode {
            scanMode = ChatScanMode(mode: mode)
            return
        }
        switch item {
        case .camera: showsCamera = true
        case .photos: showsPicker = true
        case .files: showsFiles = true
        case .focus:
            focusPlan = FocusPlan(
                workMinutes: FocusPlan.defaultMinutes(dailyMinutes: OnboardingPreferences.dailyMinutes),
                courseID: session.courseID,
                courseTitle: session.courseTitle
            )
        case .quiz:
            guard let courseID = session.courseID else { return }
            let target = courseID
            var descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            quizCourse = try? modelContext.fetch(descriptor).first
        default:
            break
        }
    }

    private var lessonChoice: Binding<ChatCardChoice?> {
        Binding(
            get: { choosingLessonFor.map(ChatCardChoice.init) },
            set: { choosingLessonFor = $0?.id }
        )
    }

    private func actions(_ session: ChatSession) -> ChatActions {
        ChatActions(
            close: { (onClose ?? { dismiss() })() },
            closeSymbol: closeSymbol,
            history: {
                focused = false
                showsHistory = true
            },
            new: {
                session.startOver()
                focused = true
            },
            camera: {
                focused = false
                showsCamera = true
            },
            library: { images in session.add(photos: images) },
            tools: {
                focused = false
                showsTools = true
            },
            clearMode: { session.clearPendingMode() },
            removePhoto: { session.remove(photo: $0) },
            send: { send(session, nil) },
            suggestion: { text in send(session, text) },
            retry: {
                Task { await session.retry(isPro: isPro, service: aiService, context: modelContext) }
            },
            unlock: { session.paywall = .mika },
            addCard: { id in addCard(id, session: session) },
            makeLesson: {
                guard let seed = session.lessonSeed, let onMakeLesson else { return }
                Analytics.track(.chatGateway, ["kind": .text("lesson")])
                onMakeLesson(seed)
            }
        )
    }

    private func prepare() {
        guard session == nil else { return }
        let created = ChatSession(launch: launch, context: modelContext)
        session = created
        Analytics.track(.chatOpened, ["origin": .text(launch.origin.rawValue), "resumed": .flag(created.thread != nil)])
        if let capture = launch.scan?.capture {
            created.queueScan(capture)
            send(created, nil)
        } else if let text = launch.autoSend?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            created.draft = text
            send(created, nil)
        } else if launch.opensCamera {
            showsCamera = true
        } else if launch.prefill != nil {
            focused = true
        }
    }

    private func send(_ session: ChatSession, _ suggestion: String?) {
        Task {
            if let suggestion { session.draft = suggestion }
            await session.send(isPro: isPro, service: aiService, context: modelContext)
            if session.paywall != nil { focused = false }
        }
    }

    /// La carte (ou les cartes) rejoint la leçon de la conversation ; sans leçon, l'élève
    /// choisit laquelle, ou en crée une.
    private func addCard(_ id: UUID, session: ChatSession) {
        if let courseID = session.courseID {
            let target = courseID
            var descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            if let course = try? modelContext.fetch(descriptor).first {
                if session.bubbles.first(where: { $0.id == id })?.cards.isEmpty == false {
                    session.addCards(of: id, to: course, in: modelContext)
                } else {
                    session.addCard(of: id, to: course, in: modelContext)
                }
                return
            }
        }
        choosingLessonFor = id
    }
}

private struct ChatCardChoice: Identifiable {
    let id: UUID
}

/// Le mode avec lequel la caméra s'ouvre depuis la conversation.
private struct ChatScanMode: Identifiable {
    let mode: ScanMode
    var id: String { mode.rawValue }
}

/// Les gestes de l'écran, posés une fois : la vue se dessine sans connaître la base.
struct ChatActions {
    var close: () -> Void = {}
    var closeSymbol = "xmark"
    var history: () -> Void = {}
    var new: () -> Void = {}
    var camera: () -> Void = {}
    var library: ([UIImage]) -> Void = { _ in }
    /// Lot 12 — le « + » : la feuille Outils.
    var tools: () -> Void = {}
    /// Lot 12 — retirer le geste en attente (« Traduire en anglais »).
    var clearMode: () -> Void = {}
    var removePhoto: (UUID) -> Void = { _ in }
    var send: () -> Void = {}
    var suggestion: (String) -> Void = { _ in }
    var retry: () -> Void = {}
    var unlock: () -> Void = {}
    var addCard: (UUID) -> Void = { _ in }
    var makeLesson: () -> Void = {}
}

// MARK: - La conversation, dessinée

/// La conversation telle qu'elle se dessine : la barre du haut, le fil, les photos en attente,
/// la barre de saisie. `still` la pose sans défilement (les rendus).
struct ChatConversationView: View {
    let session: ChatSession
    var focused: FocusState<Bool>.Binding
    var showsMakeLesson = false
    var actions = ChatActions()
    var still = false

    var body: some View {
        VStack(spacing: 0) {
            ChatTopBar(title: session.title, subtitle: session.courseTitle, isEmpty: session.isEmpty, actions: actions)
            if still {
                // Le fil posé en bas, coupé en haut comme un fil qui a défilé : il ne pousse
                // ni la barre du haut ni la barre de saisie hors de l'écran.
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottom) {
                        thread.fixedSize(horizontal: false, vertical: true)
                    }
                    .clipped()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        thread
                        Color.clear.frame(height: 1).id(ChatConversationView.bottomID)
                    }
                    .defaultScrollAnchor(.bottom)
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: session.bubbles.count) { _, _ in
                        withAnimation(MicaboMotion.standard) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                    }
                    .onChange(of: session.thinking) { _, _ in
                        withAnimation(MicaboMotion.standard) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                    }
                    .onChange(of: focused.wrappedValue) { _, isFocused in
                        guard isFocused else { return }
                        withAnimation(MicaboMotion.standard) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                    }
                }
            }
            ChatComposer(session: session, focused: focused, actions: actions, still: still)
        }
        .background(V3Color.bg.ignoresSafeArea())
    }

    static let bottomID = "chat.bottom"

    private var thread: some View {
        ChatThreadContent(session: session, showsMakeLesson: showsMakeLesson, actions: actions)
            .padding(.horizontal, V3Metric.screenMargin)
            .padding(.top, 8)
            .padding(.bottom, 16)
    }
}

/// **La barre du haut** : sortir, le titre de la conversation (et sa leçon), l'historique, une
/// nouvelle conversation.
struct ChatTopBar: View {
    let title: String
    var subtitle: String?
    var isEmpty = true
    let actions: ChatActions

    var body: some View {
        HStack(spacing: 10) {
            round(actions.closeSymbol, label: L10n.t(actions.closeSymbol == "xmark" ? "ios.cal.close" : "app.common.back", locale: .resolved()), action: actions.close)
                .flipsForRightToLeftLayoutDirection(actions.closeSymbol != "xmark")
            VStack(spacing: 1) {
                Text(title)
                    .font(V3Font.cardTitle)
                    .foregroundStyle(V3Color.ink)
                    .lineLimit(1)
                if let subtitle {
                    Label {
                        Text(subtitle).lineLimit(1)
                    } icon: {
                        Image(systemName: "book.fill")
                    }
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink2)
                    .labelStyle(.titleAndIcon)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            round("clock.arrow.circlepath", label: L10n.t("ios.chat11.history.title", locale: .resolved()), action: actions.history)
            round("square.and.pencil", label: L10n.t("ios.chat11.new", locale: .resolved()), action: actions.new)
                .opacity(isEmpty ? 0.4 : 1)
                .disabled(isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func round(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(V3Font.text(.body, weight: .bold))
                .foregroundStyle(V3Color.ink)
                .frame(width: 44, height: 44)
                .background(V3Color.surface, in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
        .accessibilityLabel(Text(label))
    }
}

// MARK: - Le fil

/// Le fil : l'accueil tant qu'il est vide, les messages, Mika qui écrit, la panne, la limite.
struct ChatThreadContent: View {
    let session: ChatSession
    var showsMakeLesson = false
    let actions: ChatActions

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if session.isEmpty {
                ChatEmptyState(courseTitle: session.courseTitle, onSuggestion: actions.suggestion, onCamera: actions.camera)
            }
            ForEach(session.bubbles) { bubble in
                ChatBubbleView(
                    bubble: bubble,
                    isLast: bubble.id == session.bubbles.last?.id,
                    showsMakeLesson: showsMakeLesson && session.lessonTopic != nil,
                    actions: actions
                )
                .id(bubble.id)
            }
            if session.thinking {
                ChatThinkingRow()
            }
            if let failure = session.failure {
                ChatNoticeCard(
                    symbol: "wifi.exclamationmark",
                    text: failure,
                    tone: V3Color.redWash,
                    button: session.canRetry ? L10n.t("lesson.path.retry", locale: .resolved()) : nil,
                    action: actions.retry
                )
            }
            if session.capReached {
                ChatNoticeCard(symbol: "moon.zzz.fill", text: L10n.t("lesson.mika.capReached", locale: .resolved()), tone: V3Color.yellowWash)
            }
            if session.limitReached {
                ChatLimitCard(onUnlock: actions.unlock)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// **L'accueil d'une conversation vide** : Mika dit ce qu'il fait, et trois idées.
struct ChatEmptyState: View {
    var courseTitle: String?
    let onSuggestion: (String) -> Void
    let onCamera: () -> Void

    private var suggestions: [String] {
        let keys = courseTitle == nil
            ? ["ios.chat11.suggest.explain", "ios.chat11.suggest.method", "ios.chat11.suggest.check"]
            : ["ios.chat11.suggest.summary", "ios.chat11.suggest.quizMe", "ios.chat11.suggest.key"]
        return keys.map { L10n.t($0, locale: .resolved()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let courseTitle {
                MikaAsk(L10n.t("ios.chat11.empty.lesson", locale: .resolved(), vars: ["lesson": courseTitle]), highlight: courseTitle, mood: .wave)
            } else {
                MikaAsk(L10n.t("ios.chat11.empty.title", locale: .resolved()), highlight: L10n.t("ios.chat11.empty.highlight", locale: .resolved()), mood: .wave)
            }
            VStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    row(suggestion, symbol: "sparkles", tone: V3Color.iconBlue) { onSuggestion(suggestion) }
                }
                if courseTitle == nil {
                    row(L10n.t("ios.chat11.suggest.photo", locale: .resolved()), symbol: "camera.fill", tone: V3Color.iconPink, action: onCamera)
                }
            }
            .padding(.top, 6)
        }
    }

    private func row(_ title: String, symbol: String, tone: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(V3Font.text(.body, weight: .bold))
                    .foregroundStyle(tone)
                    .frame(width: 26)
                Text(title)
                    .font(V3Font.option)
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: V3Metric.optionHeight)
            .v3Card(radius: V3Metric.radiusInner)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
    }
}

/// Un message : la question de l'élève à droite (ses photos au-dessus), la réponse de Mika en
/// pleine largeur, sa carte, et les passerelles sous la dernière réponse.
struct ChatBubbleView: View {
    let bubble: ChatBubble
    var isLast = false
    var showsMakeLesson = false
    let actions: ChatActions

    var body: some View {
        if bubble.role == .user {
            VStack(alignment: .trailing, spacing: 8) {
                if let mode = bubble.scanMode {
                    ChatModeTag(label: ScanPrompts.label(mode, target: bubble.scanTarget), mode: mode)
                }
                if bubble.exerciseID != nil {
                    Label(L10n.t("ios.chat11.scanned", locale: .resolved()), systemImage: "viewfinder")
                        .font(V3Font.eyebrow)
                        .foregroundStyle(V3Color.ink3)
                }
                if !bubble.photoNames.isEmpty {
                    ChatPhotoStrip(names: bubble.photoNames)
                }
                if !bubble.text.isEmpty {
                    Text(bubble.exerciseID != nil ? KeywordText.plain(bubble.text) : bubble.text)
                        .font(V3Font.text(.body, weight: .medium))
                        .foregroundStyle(V3Color.ink)
                        .lineLimit(bubble.exerciseID != nil ? 6 : nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            V3Color.accentWash,
                            in: UnevenRoundedRectangle(
                                topLeadingRadius: V3Metric.radiusBubble,
                                bottomLeadingRadius: V3Metric.radiusBubble,
                                bottomTrailingRadius: V3Metric.radiusBubbleTail,
                                topTrailingRadius: V3Metric.radiusBubble,
                                style: .continuous
                            )
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 48)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    MikaMascot(mood: .idle, size: 28)
                        .accessibilityHidden(true)
                    Text("Mika")
                        .font(V3Font.label)
                        .foregroundStyle(V3Color.ink2)
                }
                SolverRichText(source: bubble.text, size: 16.5, color: V3Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !bubble.cards.isEmpty {
                    ChatCardsProposal(cards: bubble.cards, added: bubble.cardAdded) { actions.addCard(bubble.id) }
                } else if let card = bubble.card {
                    ChatCardProposal(card: card, added: bubble.cardAdded) { actions.addCard(bubble.id) }
                }
                if isLast && showsMakeLesson {
                    V3Chip(L10n.t("ios.chat11.gateway.lesson", locale: .resolved()), icon: .book, action: actions.makeLesson)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Les photos d'un message, en vignettes alignées à droite.
struct ChatPhotoStrip: View {
    let names: [String]
    var store: ChatPhotoStore = .shared

    var body: some View {
        HStack(spacing: 6) {
            ForEach(names.prefix(4), id: \.self) { name in
                ZStack {
                    if let image = store.image(named: name) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        V3Color.soft
                        Image(systemName: "photo").foregroundStyle(V3Color.ink3)
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if name == names.prefix(4).last, names.count > 4 {
                        Text("+\(names.count - 4)")
                            .font(V3Font.label)
                            .foregroundStyle(Color.white)
                            .padding(6)
                            .background(Color.black.opacity(0.55), in: Capsule())
                            .padding(4)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.t("ios.chat11.title.photos", locale: .resolved(), vars: ["count": "\(names.count)"])))
    }
}

/// La carte que Mika propose : la question, la réponse, et « Ajouter à mes cartes ».
struct ChatCardProposal: View {
    let card: GeneratedFlashcard
    let added: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.t("ios.chat11.card.title", locale: .resolved()), systemImage: "rectangle.on.rectangle.angled")
                .font(V3Font.eyebrow)
                .foregroundStyle(V3Color.accentBright)
            Text(card.front)
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(card.back)
                .font(V3Font.body)
                .foregroundStyle(V3Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onAdd) {
                Label(
                    L10n.t(added ? "ios.chat11.card.added" : "ios.chat11.card.add", locale: .resolved()),
                    systemImage: added ? "checkmark.circle.fill" : "plus.circle.fill"
                )
                .font(V3Font.label)
                .foregroundStyle(added ? V3Color.green : V3Color.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(added ? V3Color.greenWash : V3Color.soft, in: Capsule())
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
            .disabled(added)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card(radius: V3Metric.radiusInner)
    }
}

/// **Les cartes d'une page** (lot 12) : un vocabulaire relevé ou des cartes mémoire. L'aperçu
/// montre les premières, et un seul bouton les range toutes dans une leçon (choisie, ou nouvelle).
struct ChatCardsProposal: View {
    let cards: [GeneratedFlashcard]
    let added: Bool
    let onAdd: () -> Void

    static let preview = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.t("ios.scan12.cards.title", locale: .resolved(), vars: ["count": "\(cards.count)"]), systemImage: "rectangle.on.rectangle.angled")
                .font(V3Font.eyebrow)
                .foregroundStyle(V3Color.accentBright)
            VStack(spacing: 0) {
                ForEach(Array(cards.prefix(Self.preview).enumerated()), id: \.offset) { index, card in
                    VStack(alignment: .leading, spacing: 3) {
                        SolverRichText(source: card.front, size: 15.5, color: V3Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        SolverRichText(source: card.back, size: 14.5, color: V3Color.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) {
                        if index > 0 { Rectangle().fill(V3Color.line).frame(height: 1) }
                    }
                }
            }
            if cards.count > Self.preview {
                Text(L10n.t("ios.scan12.cards.more", locale: .resolved(), vars: ["count": "\(cards.count - Self.preview)"]))
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink3)
            }
            Button(action: onAdd) {
                Label(
                    L10n.t(added ? "ios.scan12.cards.added" : "ios.scan12.cards.add", locale: .resolved(), vars: ["count": "\(cards.count)"]),
                    systemImage: added ? "checkmark.circle.fill" : "plus.circle.fill"
                )
                .font(V3Font.label)
                .foregroundStyle(added ? V3Color.green : V3Color.ctaInk)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(added ? V3Color.greenWash : V3Color.cta, in: Capsule())
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
            .disabled(added)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card(radius: V3Metric.radiusInner)
    }
}

/// **Le geste de la caméra**, en pastille : sur la bulle de l'élève (« Traduire en anglais »),
/// ou au-dessus de la barre tant qu'il attend son envoi (alors retirable).
struct ChatModeTag: View {
    let label: String
    var mode: ScanMode?
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: mode?.symbol ?? "camera.viewfinder")
                .font(V3Font.text(.footnote, weight: .bold))
                .foregroundStyle(mode?.tone ?? V3Color.iconPink)
            Text(label)
                .font(V3Font.label)
                .foregroundStyle(V3Color.ink)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(V3Font.text(.caption2, weight: .heavy))
                        .foregroundStyle(V3Color.ink2)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
                .accessibilityLabel(Text(L10n.t("ios.scan12.mode.remove", locale: .resolved())))
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, onRemove == nil ? 12 : 4)
        .frame(minHeight: 32)
        .background(V3Color.soft, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// Mika écrit.
struct ChatThinkingRow: View {
    var body: some View {
        HStack(spacing: 8) {
            MikaMascot(mood: .think, size: 28)
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(V3Color.ink3).frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(V3Color.surface, in: Capsule())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.t("ios.chat11.thinking", locale: .resolved())))
    }
}

/// Un message de service : la panne (avec « Réessayer »), le plafond du jour.
struct ChatNoticeCard: View {
    let symbol: String
    let text: String
    let tone: Color
    var button: String?
    var action: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .font(V3Font.text(.body, weight: .bold))
                    .foregroundStyle(V3Color.ink2)
                Text(text)
                    .font(V3Font.body)
                    .foregroundStyle(V3Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let button {
                V3Button(button, systemImage: "arrow.clockwise", kind: .secondary, action: action)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card(tone: tone, radius: V3Metric.radiusInner)
    }
}

/// **La question offerte est passée** : dit dans le fil, avec la porte du paywall existant.
struct ChatLimitCard: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            V3ProBadge(nil)
            Text(L10n.t("ios.chat11.limit.title", locale: .resolved()))
                .font(V3Font.cardTitle)
                .foregroundStyle(V3Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t("ios.chat11.limit.body", locale: .resolved()))
                .font(V3Font.body)
                .foregroundStyle(V3Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            V3Button(L10n.t("ios.chat11.limit.cta", locale: .resolved()), kind: .offer, action: onUnlock)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card(tone: V3Color.yellowWash, radius: V3Metric.radiusCard)
    }
}

// MARK: - La barre de saisie

/// **La barre de saisie** : les photos en attente au-dessus (retirables), puis le rond
/// photothèque, et la pilule — le champ, l'appareil photo, ou la flèche d'envoi dès qu'il y a
/// quelque chose à envoyer. Seule à lire ce que l'élève tape : une frappe ne redessine qu'elle.
struct ChatComposer: View {
    let session: ChatSession
    var focused: FocusState<Bool>.Binding
    let actions: ChatActions
    var still = false

    static let height: CGFloat = 52

    var body: some View {
        @Bindable var session = session
        VStack(alignment: .leading, spacing: 10) {
            if let label = session.pendingLabel {
                ChatModeTag(label: label, mode: session.pendingMode, onRemove: actions.clearMode)
                    .padding(.horizontal, V3Metric.screenMargin)
            }
            if !session.pending.isEmpty {
                ChatPendingRow(photos: session.pending, onRemove: actions.removePhoto)
            }
            HStack(alignment: .bottom, spacing: 10) {
                tools
                HStack(alignment: .bottom, spacing: 8) {
                    field(draft: $session.draft)
                    trailing
                }
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .frame(minHeight: Self.height)
                .background(V3Color.surface, in: RoundedRectangle(cornerRadius: Self.height / 2, style: .continuous))
            }
            .padding(.horizontal, V3Metric.screenMargin)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(V3Color.bg)
    }

    private var placeholder: String {
        session.pending.isEmpty
            ? L10n.t(session.courseTitle == nil ? "ios.chat11.placeholder" : "ios.chat11.placeholderLesson", locale: .resolved())
            : L10n.t("ios.chat11.placeholderPhotos", locale: .resolved())
    }

    /// **Le « + »** (lot 12) : la feuille Outils — la caméra, les photos, les fichiers, et les
    /// gestes de Mika (expliquer, résumer, traduire, résoudre, des cartes…).
    private var tools: some View {
        Button(action: actions.tools) {
            Image(systemName: "plus")
                .font(V3Font.text(.title3, weight: .bold))
                .foregroundStyle(V3Color.ink)
                .frame(width: Self.height, height: Self.height)
                .background(V3Color.surface, in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .disabled(session.thinking)
        .accessibilityLabel(Text(L10n.t("ios.scan12.tools.title", locale: .resolved())))
    }

    @ViewBuilder
    private func field(draft: Binding<String>) -> some View {
        Group {
            if still {
                Text(draft.wrappedValue.isEmpty ? placeholder : draft.wrappedValue)
                    .foregroundStyle(draft.wrappedValue.isEmpty ? V3Color.ink3 : V3Color.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(text: draft, prompt: Text(placeholder).foregroundStyle(V3Color.ink3), axis: .vertical) {
                    Text(placeholder)
                }
                .foregroundStyle(V3Color.ink)
                .tint(V3Color.accent)
                .lineLimit(1...5)
                .focused(focused)
            }
        }
        .font(V3Font.text(.body, weight: .medium))
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var trailing: some View {
        let hasText = !session.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasText || !session.pending.isEmpty {
            Button(action: actions.send) {
                Group {
                    if session.isReading || session.thinking {
                        ProgressView().tint(V3Color.ctaInk)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(V3Font.text(.body, weight: .heavy))
                            .foregroundStyle(V3Color.ctaInk)
                    }
                }
                .frame(width: 36, height: 36)
                .background(V3Color.cta.opacity(session.canSend ? 1 : 0.5), in: Circle())
                .frame(height: Self.height)
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
            .disabled(!session.canSend)
            .accessibilityLabel(Text(L10n.t("lesson.mika.send", locale: .resolved())))
        } else {
            Button(action: actions.camera) {
                Image(systemName: "camera")
                    .font(V3Font.text(.title3, weight: .semibold))
                    .foregroundStyle(V3Color.ink)
                    .frame(width: 36, height: Self.height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
            .disabled(!session.hasRoomForPhotos || session.thinking)
            .accessibilityLabel(Text(L10n.t("ios.chat11.camera.open", locale: .resolved())))
        }
    }
}

/// Les photos prises ou choisies, pas encore envoyées : chacune se retire d'un appui ; celle
/// qui se lit tourne, celle où rien ne s'est lu le dit.
struct ChatPendingRow: View {
    let photos: [ChatPendingPhoto]
    let onRemove: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos) { photo in
                        thumbnail(photo)
                    }
                }
                .padding(.horizontal, V3Metric.screenMargin)
                .padding(.top, 6)
            }
            if photos.contains(where: { $0.state == .unreadable }) {
                Text(L10n.t("ios.chat11.photo.unreadable", locale: .resolved()))
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, V3Metric.screenMargin)
            }
        }
    }

    private func thumbnail(_ photo: ChatPendingPhoto) -> some View {
        Image(uiImage: photo.image)
            .resizable()
            .scaledToFill()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
            .overlay {
                switch photo.state {
                case .reading:
                    ZStack {
                        RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous).fill(Color.black.opacity(0.45))
                        ProgressView().tint(.white)
                    }
                case .unreadable:
                    RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous)
                        .strokeBorder(V3Color.yellow, lineWidth: 2)
                case .read:
                    RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous)
                        .strokeBorder(V3Color.line, lineWidth: V3Metric.border)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button { onRemove(photo.id) } label: {
                    Image(systemName: "xmark")
                        .font(V3Font.text(.caption2, weight: .heavy))
                        .foregroundStyle(V3Color.ink)
                        .frame(width: 22, height: 22)
                        .background(V3Color.soft, in: Circle())
                        .overlay(Circle().strokeBorder(V3Color.bg, lineWidth: 2))
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
                .offset(x: 6, y: -6)
                .accessibilityLabel(Text(L10n.t("ios.chat11.photo.remove", locale: .resolved())))
            }
    }
}

// MARK: - Choisir la leçon d'une carte

/// Une conversation hors leçon propose une carte : l'élève choisit la leçon où elle se range.
struct ChatLessonPicker: View {
    /// Lot 12 — le nom d'une nouvelle leçon (un paquet de cartes), proposée en tête ; `nil` :
    /// seulement les leçons qui existent.
    var newLessonTitle: String?
    let onPick: (Course) -> Void
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var lessons: [Course] { courses.filter { $0.isLesson || $0.source == .deck } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let newLessonTitle {
                        V3OptionRow(L10n.t("ios.scan12.cards.newLesson", locale: .resolved()), subtitle: newLessonTitle, icon: .cards, isSelected: false) {
                            if let course = try? CourseRepository.makeDeck(title: newLessonTitle, in: modelContext) {
                                onPick(course)
                            }
                            dismiss()
                        }
                    }
                    if lessons.isEmpty && newLessonTitle == nil {
                        Text(L10n.t("ios.chat11.card.noLesson", locale: .resolved()))
                            .font(V3Font.body)
                            .foregroundStyle(V3Color.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(lessons.prefix(30)) { course in
                        V3OptionRow(course.title, icon: course.icon, isSelected: false) {
                            onPick(course)
                            dismiss()
                        }
                    }
                }
                .padding(V3Metric.screenMargin)
            }
            .background(V3Color.bg.ignoresSafeArea())
            .navigationTitle(L10n.t("ios.chat11.card.pick", locale: .resolved()))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - « Demander à Mika »

/// Le petit bouton « Demander à Mika » d'une carte ou d'une question de quiz : il ouvre une
/// conversation liée à la leçon, la question déjà posée dans le champ.
struct ChatAskButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(L10n.t("ios.chat11.ask.action", locale: .resolved()), systemImage: "bubble.left.and.text.bubble.right.fill")
                .font(V3Font.label)
                .foregroundStyle(V3Color.accentBright)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(V3Color.accentWash, in: Capsule())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
    }
}
