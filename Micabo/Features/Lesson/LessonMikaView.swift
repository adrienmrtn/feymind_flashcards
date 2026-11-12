import SwiftData
import SwiftUI

/// **Mika, dans la leçon** : le bouton bulle en haut du chemin ouvre une conversation où la
/// leçon est jointe d'office. Une conversation par leçon, gardée sur l'appareil.
///
/// La porte est celle de Mika (`MikaQuota`) : une question offerte, puis Pro ; un plafond par
/// jour pour un abonné. Quand Mika propose une carte, « Ajouter » la range dans la leçon.
///
/// Elle se lit comme le fil du tuteur (`TutorThreadContent`) : Mika en demi sur sa carte à
/// l'accueil, sa tête dans un rond à côté de chaque réponse, les trois points pendant qu'il
/// écrit, et la flèche bleue d'envoi, que le clavier ne cache jamais.
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
        MikaConversationStore.lessonsDirectory
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
                            HStack(alignment: .bottom, spacing: 10) {
                                MikaAvatar(size: 34)
                                HStack(spacing: 5) {
                                    ForEach(0..<3, id: \.self) { _ in
                                        Circle().fill(MicaboColor.inkTertiary).frame(width: 7, height: 7)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
                                Spacer(minLength: 0)
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
                    withAnimation(LearnMotion.standard) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                // Le clavier monte : la dernière réponse remonte avec lui, au-dessus du champ.
                .onChange(of: focused) { _, isFocused in
                    guard isFocused, let last = chat.messages.last else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(LearnMotion.standard) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            input(draft: $chat.draft)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .micaboPaywall($paywall)
    }

    private var header: some View {
        HStack(spacing: 12) {
            MikaAvatar(size: 36)
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

    /// L'accueil : Mika en demi au bas de sa carte (la règle de `MikaMascot`), ce qu'il propose,
    /// et trois questions toutes prêtes, rangées comme celles du tuteur.
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            SolverMikaCard(mood: .wave) {
                Text(L10n.t("lesson.mika.welcome", locale: .resolved(), vars: ["lesson": course.title]))
                    .font(MicaboFont.ui(16, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            suggestion(L10n.t("lesson.mika.suggestExplain", locale: .resolved()))
            suggestion(L10n.t("lesson.mika.suggestExample", locale: .resolved()))
            suggestion(L10n.t("lesson.mika.suggestQuiz", locale: .resolved()))
        }
        .padding(.top, 4)
    }

    private func suggestion(_ text: String) -> some View {
        Button {
            chat.draft = text
            send()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MicaboColor.accentInk)
                Text(text)
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .solverCard(radius: 16)
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }

    private func bubble(_ message: MikaMessage) -> some View {
        let mine = message.role == .user
        return HStack(alignment: .bottom, spacing: 10) {
            if !mine {
                MikaAvatar(size: 34)
            }
            VStack(alignment: mine ? .trailing : .leading, spacing: 8) {
                KeywordText(message.text, size: 16, weight: .medium, tintsKeywords: message.role != .user)
                    .font(MicaboFont.ui(16, weight: .medium))
                    .foregroundStyle(mine ? MicaboColor.onInk : MicaboColor.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        mine ? MicaboColor.ink : MicaboColor.surface,
                        in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                    )
                    .overlay {
                        if !mine {
                            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: MicaboSurface.border)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                if let card = message.card {
                    proposedCard(card, added: message.cardAdded, messageID: message.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        .padding(mine ? .leading : .trailing, mine ? 48 : 24)
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
        .background(course.tone.pale, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
    }

    private func failureRow(_ failure: String) -> some View {
        HStack(spacing: 10) {
            Text(failure)
                .font(MicaboFont.ui(14, weight: .medium))
                .foregroundStyle(MicaboColor.wrongInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if chat.canRetry {
                Button(L10n.t("lesson.path.retry", locale: .resolved())) {
                    Task { await chat.retry(level: level, language: language, using: aiService) }
                }
                .font(MicaboFont.ui(14, weight: .heavy))
                .foregroundStyle(MicaboColor.accentInk)
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
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: MicaboSurface.border))
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        draft.wrappedValue.nilIfBlank == nil || chat.isThinking ? MicaboColor.inkTertiary : MicaboBrand.blue,
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

    /// La langue de la leçon, sinon celle de l'interface : Mika répond comme le cours est écrit.
    private var language: ContentLanguage {
        course.language ?? ContentLanguage(rawValue: UiLocale.resolved().rawValue) ?? DeckSetup.defaultLanguage()
    }

    /// La carte proposée rejoint la leçon, par le même chemin que les cartes générées : texte
    /// nettoyé, format vérifié, rang après la dernière carte. Une seule fois : `.disabled` ne
    /// suit qu'au rendu suivant, et un double appui la rangeait deux fois.
    private func addCard(_ card: GeneratedFlashcard, messageID: UUID) {
        guard chat.messages.first(where: { $0.id == messageID })?.cardAdded != true else { return }
        guard let inserted = try? CourseRepository.addFlashcards([card], to: course, in: modelContext),
              !inserted.isEmpty
        else { return }
        chat.markCardAdded(messageID)
        Haptics.success()
        Analytics.track(.mikaCardAdded)
    }
}
