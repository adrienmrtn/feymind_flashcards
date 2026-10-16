import SwiftData
import SwiftUI

/// **Mika, dans la leçon** : le bouton bulle en haut du chemin ouvre une conversation où la
/// leçon est jointe d'office. Une conversation par leçon, gardée sur l'appareil.
///
/// La porte est celle de Mika (`MikaQuota`) : une question offerte, puis Pro ; un plafond par
/// jour pour un abonné. Quand Mika propose une carte, « Ajouter » la range dans la leçon.
struct LessonMikaView: View {
    let course: Course

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(ProAccess.self) private var pro: ProAccess?

    @State private var chat: MikaChat
    @State private var paywall: PaywallTrigger?
    @FocusState private var focused: Bool

    init(course: Course) {
        self.course = course
        let url = Self.storeURL(for: course.id)
        var conversation = MikaConversationStore.load(from: url)
        conversation.attachment = Self.attachment(for: course)
        _chat = State(initialValue: MikaChat(
            conversation: conversation,
            store: { MikaConversationStore.save($0, to: url) }
        ))
    }

    /// Un fichier par leçon, à côté de la conversation de l'ancien onglet.
    static func storeURL(for id: UUID) -> URL {
        MikaConversationStore.defaultURL
            .deletingLastPathComponent()
            .appendingPathComponent("mika-lessons", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).json")
    }

    /// La leçon jointe : son titre, et ses notes à plat.
    static func attachment(for course: Course) -> MikaAttachment {
        let text = course.orderedChapters
            .map { "\($0.title)\n\($0.plainText)" }
            .joined(separator: "\n\n")
            .nilIfBlank ?? course.contextSnippet(limit: MikaLimits.attachmentCharacters)
        return MikaAttachment(
            kind: .course,
            title: course.title,
            text: String(text.prefix(MikaLimits.attachmentCharacters)),
            courseID: course.id,
            emoji: nil
        )
    }

    var body: some View {
        @Bindable var chat = chat
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if chat.isEmpty {
                            welcome
                        }
                        ForEach(chat.messages) { message in
                            bubble(message).id(message.id)
                        }
                        if chat.isThinking {
                            HStack {
                                MikaMascot(mood: .think, size: 72)
                                Spacer()
                            }
                            .id("thinking")
                        }
                        if let failure = chat.failure {
                            failureRow(failure)
                        } else if chat.capReached {
                            failureRow(L10n.t("lesson.mika.capReached", locale: .resolved()))
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
            input(draft: $chat.draft)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .micaboPaywall($paywall)
    }

    private var header: some View {
        HStack(spacing: 12) {
            MicaboIconView(icon: .mika, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("Mika")
                    .font(MicaboFont.ui(18, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                Text(course.title)
                    .font(MicaboFont.ui(13, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if !chat.isEmpty {
                Button {
                    chat.reset()
                    chat.attach(Self.attachment(for: course))
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(Text(L10n.t("lesson.mika.new", locale: .resolved())))
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

    private var welcome: some View {
        VStack(spacing: 14) {
            MikaMascot(mood: .wave, size: 130)
            Text(L10n.t("lesson.mika.welcome", locale: .resolved(), vars: ["lesson": course.title]))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            VStack(spacing: 8) {
                suggestion(L10n.t("lesson.mika.suggestExplain", locale: .resolved()))
                suggestion(L10n.t("lesson.mika.suggestExample", locale: .resolved()))
                suggestion(L10n.t("lesson.mika.suggestQuiz", locale: .resolved()))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private func suggestion(_ text: String) -> some View {
        Button {
            chat.draft = text
            send()
        } label: {
            Text(text)
                .font(MicaboFont.ui(15, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity)
                .background(MicaboColor.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }

    private func bubble(_ message: MikaMessage) -> some View {
        let mine = message.role == .user
        return VStack(alignment: mine ? .trailing : .leading, spacing: 8) {
            KeywordText(message.text, size: 16, weight: .medium, tintsKeywords: message.role != .user)
                .font(MicaboFont.ui(16, weight: .medium))
                .foregroundStyle(mine ? MicaboColor.onInk : MicaboColor.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    mine ? MicaboColor.ink : MicaboColor.surface,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .fixedSize(horizontal: false, vertical: true)
            if let card = message.card {
                proposedCard(card, added: message.cardAdded, messageID: message.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        .padding(mine ? .leading : .trailing, 40)
    }

    private func proposedCard(_ card: GeneratedFlashcard, added: Bool, messageID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            KeywordText(card.front, size: 15, weight: .heavy)
                .font(MicaboFont.ui(15, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
            KeywordText(card.back, size: 14, weight: .medium)
                .font(MicaboFont.ui(14, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
            Button {
                addCard(card, messageID: messageID)
            } label: {
                Label(
                    added ? L10n.t("lesson.mika.cardAdded", locale: .resolved()) : L10n.t("lesson.mika.addCard", locale: .resolved()),
                    systemImage: added ? "checkmark" : "plus"
                )
                .font(MicaboFont.ui(14, weight: .heavy))
                .foregroundStyle(added ? MicaboColor.correctInk : course.tone.ink)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .disabled(added)
        }
        .padding(14)
        .background(course.tone.pale, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func failureRow(_ failure: String) -> some View {
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

    private func input(draft: Binding<String>) -> some View {
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
            .disabled(draft.wrappedValue.nilIfBlank == nil || chat.isThinking)
            .accessibilityLabel(Text(L10n.t("lesson.mika.send", locale: .resolved())))
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.vertical, 10)
        .background(MicaboColor.canvas)
    }

    private func send() {
        Task {
            let gate = await chat.send(isPro: pro?.isPro ?? false, level: level, language: language, using: aiService)
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

    /// La langue de la leçon, sinon celle de l'interface : Mika répond comme le cours est écrit.
    private var language: ContentLanguage {
        course.language ?? ContentLanguage(rawValue: UiLocale.resolved().rawValue) ?? DeckSetup.defaultLanguage()
    }

    private func addCard(_ card: GeneratedFlashcard, messageID: UUID) {
        let flashcard = Flashcard(front: card.front, back: card.back, position: course.cards.count, course: course)
        modelContext.insert(flashcard)
        course.updatedAt = Date()
        try? modelContext.save()
        chat.markCardAdded(messageID)
        Haptics.success()
    }
}
