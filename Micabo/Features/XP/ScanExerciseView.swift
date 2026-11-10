import PhotosUI
import SwiftUI
import UIKit

/// **Scanner un exo** (`docs/refonte-knowunity.md` § 4) : l'appareil photo (le scanner de
/// document là où il existe) ou la photothèque, une seule page, lue **sur l'appareil**
/// (`OnDeviceOCR`, celui des imports) ; puis une conversation avec Mika, hors leçon, où la page
/// est jointe et la première demande part toute seule.
///
/// La conversation reprend le modèle du chat de la leçon (`MikaChat`) et sa porte
/// (`MikaQuota` : une question offerte, puis le paywall `mika`). **Elle ne s'écrit nulle
/// part** : ni dans le fichier de l'ancien onglet Mika, ni dans celui d'une leçon. Un exercice
/// se scanne, s'explique, et s'oublie en fermant l'écran.
struct ScanExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.aiService) private var aiService
    @Environment(ProAccess.self) private var pro: ProAccess?

    private enum Phase: Equatable {
        case choose
        case reading
        case unreadable
        case chat
    }

    /// En dessous, la photo n'a rien donné de lisible.
    static let minimumCharacters = 12

    @State private var phase: Phase = .choose
    @State private var chat: MikaChat?
    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var paywall: PaywallTrigger?
    /// La lecture de la page en cours, annulée quand l'écran se ferme.
    @State private var reader: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            switch phase {
            case .choose: choose
            case .reading: reading
            case .unreadable: unreadable
            case .chat:
                if let chat { conversation(chat) }
            }
        }
        .animation(.spring(duration: 0.4), value: phase)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItems, maxSelectionCount: 1, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard let item = items.first else { return }
            photoItems = []
            readPhoto(item)
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentCameraView { images in
                showScanner = false
                read(images)
            } onCancel: {
                showScanner = false
            }
            .ignoresSafeArea()
        }
        .micaboPaywall($paywall)
        .onDisappear { reader?.cancel() }
    }

    // MARK: L'en-tête

    private var header: some View {
        HStack(spacing: 12) {
            MicaboIconView(icon: .mika, size: 36)
            Text(L10n.t("ios.kx.scan.title", locale: .resolved()))
                .font(MicaboFont.ui(18, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if phase == .chat {
                Button(action: startOver) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(Text(L10n.t("ios.kx.scan.again", locale: .resolved())))
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(Text(L10n.t("lesson.circle.close", locale: .resolved())))
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.vertical, 10)
    }

    // MARK: Choisir la photo

    private var canScan: Bool {
        DocumentCameraView.isSupported && CameraAccess.allowsScanner(CameraAccess.status)
    }

    private var choose: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            MicaboSpeechBubble(text: L10n.t("ios.kx.scan.prompt", locale: .resolved()), tail: .bottom)
                .padding(.horizontal, 28)
            MikaMascot(mood: .wave, size: 150, reactsToTap: true, frame: .circle)
                .padding(.top, 16)
            Spacer(minLength: 12)
            VStack(spacing: 12) {
                if canScan {
                    Button(action: openCamera) {
                        Label(L10n.t("ios.kx.scan.camera", locale: .resolved()), systemImage: "camera.fill")
                    }
                    .buttonStyle(LessonPrimaryButtonStyle())
                }
                Button {
                    showPhotoPicker = true
                } label: {
                    Label(L10n.t("ios.kx.scan.library", locale: .resolved()), systemImage: "photo.on.rectangle")
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, 16)
        }
        .transition(.opacity)
    }

    private var reading: some View {
        VStack(spacing: 18) {
            Spacer()
            MikaMascot(mood: .think, size: 150, frame: .circle)
            Text(L10n.t("ios.kx.scan.reading", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            ProgressView()
                .tint(MicaboColor.accent)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    private var unreadable: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            MicaboSpeechBubble(text: L10n.t("ios.kx.scan.unreadable", locale: .resolved()), tail: .bottom)
                .padding(.horizontal, 28)
            MikaMascot(mood: .sad, size: 140, frame: .circle)
                .padding(.top, 16)
            Spacer(minLength: 12)
            Button(action: startOver) {
                Label(L10n.t("ios.kx.scan.retry", locale: .resolved()), systemImage: "camera.fill")
            }
            .buttonStyle(LessonPrimaryButtonStyle())
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, 16)
        }
        .transition(.opacity)
    }

    private func openCamera() {
        // La question système d'abord, et le scanner seulement sur un oui : refusée dans le
        // scanner, la caméra y laisserait l'impasse de VisionKit (voir `CameraAccess`).
        Task {
            if await CameraAccess.request() {
                showScanner = true
            } else {
                showPhotoPicker = true
            }
        }
    }

    private func startOver() {
        focused = false
        chat = nil
        phase = .choose
    }

    // MARK: Lire

    private func readPhoto(_ item: PhotosPickerItem) {
        phase = .reading
        reader?.cancel()
        reader = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            guard !Task.isCancelled else { return }
            if let data, let image = UIImage(data: data) {
                read([image])
            } else {
                phase = .unreadable
            }
        }
    }

    /// Une seule page : la première, si le scanner en a pris plusieurs.
    private func read(_ images: [UIImage]) {
        guard let page = images.first else { return }
        phase = .reading
        reader?.cancel()
        reader = Task {
            let text = await OnDeviceOCR.recognize(images: [page])
            // L'élève a pu fermer l'écran pendant la lecture : la page n'ouvre plus de
            // conversation dans son dos, et ne consomme pas la question offerte.
            guard !Task.isCancelled, phase == .reading else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= Self.minimumCharacters else {
                Haptics.warning()
                phase = .unreadable
                return
            }
            start(with: trimmed)
        }
    }

    private func start(with text: String) {
        let attachment = MikaAttachment(
            kind: .document,
            title: L10n.t("ios.kx.scan.attachment", locale: .resolved()),
            text: String(text.prefix(MikaLimits.attachmentCharacters)),
            courseID: nil,
            emoji: nil
        )
        let chat = MikaChat(
            conversation: MikaConversation(messages: [], attachment: attachment),
            store: { _ in },
            firstReward: .exerciseSolved
        )
        chat.draft = L10n.t("ios.kx.scan.firstMessage", locale: .resolved())
        self.chat = chat
        phase = .chat
        send()
    }

    // MARK: La conversation

    private func conversation(_ chat: MikaChat) -> some View {
        @Bindable var chat = chat
        return VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        attachmentChip
                        ForEach(chat.messages) { message in
                            bubble(message).id(message.id)
                        }
                        if chat.isThinking {
                            HStack {
                                MikaMascot(mood: .think, size: 64, frame: .circle)
                                Spacer()
                            }
                            .id("thinking")
                        }
                        if let failure = chat.failure {
                            failureRow(failure, chat: chat)
                        } else if chat.capReached {
                            failureRow(L10n.t("lesson.mika.capReached", locale: .resolved()), chat: chat)
                        }
                    }
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: chat.messages.count) { _, _ in
                    guard let last = chat.messages.last else { return }
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            input(draft: $chat.draft, thinking: chat.isThinking)
        }
        .transition(.opacity)
    }

    private var attachmentChip: some View {
        HStack(spacing: 8) {
            MicaboIconView(icon: .photo, size: 22)
            Text(L10n.t("ios.kx.scan.attachment", locale: .resolved()))
                .font(MicaboFont.ui(14, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(MicaboColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(MicaboColor.stroke, lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func bubble(_ message: MikaMessage) -> some View {
        let mine = message.role == .user
        return KeywordText(message.text, size: 16, weight: .medium, tintsKeywords: !mine)
            .font(MicaboFont.ui(16, weight: .medium))
            .foregroundStyle(mine ? MicaboColor.onInk : MicaboColor.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                mine ? MicaboColor.ink : MicaboColor.surface,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
            .padding(mine ? .leading : .trailing, 40)
    }

    private func failureRow(_ failure: String, chat: MikaChat) -> some View {
        HStack(spacing: 10) {
            Text(failure)
                .font(MicaboFont.ui(14, weight: .medium))
                .foregroundStyle(MicaboColor.wrongInk)
            Spacer()
            if chat.canRetry {
                Button(L10n.t("lesson.path.retry", locale: .resolved())) {
                    Task { await chat.retry(level: level, language: language, using: aiService) }
                }
                .font(MicaboFont.ui(14, weight: .heavy))
            }
        }
    }

    private func input(draft: Binding<String>, thinking: Bool) -> some View {
        HStack(spacing: 10) {
            TextField(L10n.t("lesson.mika.placeholder", locale: .resolved()), text: draft, axis: .vertical)
                .font(MicaboFont.ui(16, weight: .medium))
                .lineLimit(1...5)
                .focused($focused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(MicaboColor.onInk)
                    .frame(width: 44, height: 44)
                    .background(
                        draft.wrappedValue.nilIfBlank == nil ? MicaboColor.inkTertiary : MicaboColor.ink,
                        in: Circle()
                    )
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
            .disabled(draft.wrappedValue.nilIfBlank == nil || thinking)
            .accessibilityLabel(Text(L10n.t("lesson.mika.send", locale: .resolved())))
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.vertical, 10)
        .background(MicaboColor.canvas)
    }

    private func send() {
        guard let chat else { return }
        Task {
            let isPro = pro?.isPro ?? false
            let gate = await chat.send(isPro: isPro, level: level, language: language, using: aiService)
            MikaChat.track(gate, isPro: isPro, chat: chat)
            switch gate {
            case .paywall:
                focused = false
                paywall = .mika
            case .dailyCapReached:
                Haptics.warning()
            case .allowed, nil:
                break
            }
        }
    }

    private var level: StudyLevel? {
        OnboardingPreferences.educationStage?.level
    }

    /// Mika répond dans la langue de l'app.
    private var language: ContentLanguage {
        ContentLanguage(rawValue: UiLocale.resolved().rawValue) ?? DeckSetup.defaultLanguage()
    }
}
