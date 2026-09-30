import SwiftData
import SwiftUI

/// **Mika, l'onglet : un chat avec l'assistant du parcours d'accueil.**
///
/// Une seule conversation, gardée sur l'appareil ; un champ en bas, sans style ; les
/// réponses d'un bloc, balisées comme la fiche, avec le blob de Mika qui respire à côté.
/// Pendant que Mika réfléchit, un petit blob s'agite sous le dernier message : c'est le même
/// geste que le chargement du parcours.
///
/// **La première question est offerte, les suivantes sont dans Premium** : la porte
/// (`MikaQuota`) se passe avant l'appel, et c'est ici que le paywall s'ouvre. Un abonné a un
/// plafond par jour qu'il ne voit qu'en l'atteignant.
///
/// **Le champ se pose sur le clavier, sans la barre d'onglets entre les deux.** Pendant
/// qu'on tape, la page se déclare « poussée » auprès du routeur : la barre se retire, comme
/// sur un écran de détail, et revient quand le clavier se range.
struct MikaView: View {
    @Environment(TabRouter.self) private var router: TabRouter?
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.aiService) private var aiService
    @Environment(\.modelContext) private var modelContext

    @State private var chat = MikaChat()
    @State private var path = NavigationPath()
    @State private var paywall: PaywallTrigger?
    @State private var showCoursePicker = false
    @State private var showDocumentSheet = false
    /// Le message dont on range la carte, quand il faut d'abord choisir le cours.
    @State private var cardToPlace: MikaMessage?
    @FocusState private var isComposing: Bool

    private static let bottomAnchor = "mika.bottom"

    private var isPro: Bool { pro?.isPro ?? false }

    private var canSend: Bool {
        !chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chat.isThinking
    }

    /// La place de la barre d'onglets, sous le champ : rien pendant qu'on tape, la barre
    /// s'étant retirée.
    private var barReserve: CGFloat {
        (router?.isAtRoot ?? true) ? MicaboLayout.tabBarSpace : 0
    }

    var body: some View {
        @Bindable var chat = chat

        return NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MicaboSpacing.md) {
                        if chat.isEmpty {
                            welcome
                        } else {
                            ForEach(chat.messages) { message in
                                row(message)
                            }
                        }

                        if chat.isThinking {
                            thinkingRow
                        }

                        if let failure = chat.failure {
                            failureRow(failure)
                        }

                        if chat.capReached {
                            noticeRow(i18n.t("ios.mika.chat.capReached"))
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(Self.bottomAnchor)
                    }
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.vertical, MicaboSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: chat.messages.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: chat.isThinking) { _, _ in scrollToBottom(proxy) }
                .onChange(of: isComposing) { _, focused in
                    if focused { scrollToBottom(proxy) }
                }
            }
            .micaboScreenBackground()
            .safeAreaInset(edge: .top, spacing: 0) { topBar }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    composer($chat.draft)
                    Color.clear
                        .frame(height: barReserve)
                        .allowsHitTesting(false)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .reportsNavigationDepth(for: .mika, depth: isComposing ? 1 : 0)
            .returnsHome(path: $path)
        }
        .micaboPaywall($paywall)
        .sheet(isPresented: $showCoursePicker) {
            MikaCoursePicker(title: i18n.t("ios.mika.chat.pickCourse")) { course in
                attach(course)
                showCoursePicker = false
            }
        }
        .sheet(item: $cardToPlace) { message in
            MikaCoursePicker(title: i18n.t("ios.mika.chat.cardWhere")) { course in
                add(message, to: course)
                cardToPlace = nil
            }
        }
        .sheet(isPresented: $showDocumentSheet) {
            MikaDocumentSheet { attachment in
                chat.attach(attachment)
                showDocumentSheet = false
                Haptics.light()
            }
        }
    }

    // MARK: - Le haut

    private var topBar: some View {
        HStack(spacing: 10) {
            MikaBlob(size: 34, wobble: 0.14, speed: 0.22)
                .accessibilityHidden(true)

            Text(i18n.t("ios.mika.chat.title"))
                .font(MicaboFont.ui(22, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(MicaboColor.ink)

            Spacer(minLength: 0)

            if !chat.isEmpty {
                MicaboCircleButton(
                    systemImage: "square.and.pencil",
                    size: 36,
                    accessibilityTitle: i18n.t("ios.mika.chat.new")
                ) {
                    newConversation()
                }
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.vertical, 10)
        .background(MicaboColor.canvas)
    }

    // MARK: - L'accueil

    /// La conversation vide : le blob en grand, une phrase, et trois questions qu'on peut
    /// poser d'un appui pour voir ce que ça donne.
    private var welcome: some View {
        VStack(spacing: 14) {
            MikaBlob(size: 150)
                .padding(.top, MicaboSpacing.lg)
                .accessibilityHidden(true)

            Text(i18n.t("ios.mika.chat.hello"))
                .font(MicaboFont.ui(28, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)

            Text(i18n.t("ios.mika.chat.intro"))
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MicaboSpacing.md)

            // Rien ne dit que la première question est offerte : on pose sa question, on
            // a sa réponse, et c'est à la deuxième qu'on découvre que la suite est dans Pro.
            VStack(spacing: 8) {
                ForEach(1...3, id: \.self) { index in
                    suggestion(i18n.t("ios.mika.chat.suggestion\(index)"))
                }
            }
            .padding(.top, MicaboSpacing.sm)
        }
        .frame(maxWidth: .infinity)
    }

    private func suggestion(_ text: String) -> some View {
        Button {
            chat.draft = text
            Task { await send() }
        } label: {
            HStack(spacing: 10) {
                Text(text)
                    .font(MicaboFont.ui(15, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .micaboGroup(radius: MicaboRadius.lg)
            .contentShape(RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .light))
    }

    // MARK: - Les messages

    @ViewBuilder
    private func row(_ message: MikaMessage) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .font(MicaboFont.body)
                    .foregroundStyle(MicaboColor.onInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(MicaboColor.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .textSelection(.enabled)

        case .mika:
            HStack(alignment: .top, spacing: 10) {
                MikaBlob(size: 24, wobble: 0.14, speed: 0.22)
                    .padding(.top, 2)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    // Les paragraphes, un par un : une ligne vide dans la réponse est un
                    // vrai saut, pas un retour à la ligne.
                    ForEach(Array(paragraphs(of: message.text).enumerated()), id: \.offset) { _, paragraph in
                        SheetInlineText(markup: paragraph, style: .prose)
                            .textSelection(.enabled)
                    }

                    if let card = message.card {
                        cardOffer(message, card)
                    }
                }
                .padding(.trailing, MicaboSpacing.md)
            }
        }
    }

    private func paragraphs(of text: String) -> [String] {
        let pieces = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return pieces.isEmpty ? [text] : pieces
    }

    /// La carte que Mika propose, et le bouton qui la range. Le bouton ne se répète pas une
    /// fois la carte écrite : il dit ce qui a été fait.
    private func cardOffer(_ message: MikaMessage, _ card: GeneratedFlashcard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(FormulaRenderer.stripped(card.front))
                    .font(MicaboFont.ui(14.5, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(FormulaRenderer.stripped(card.back))
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .micaboGroup(radius: MicaboRadius.lg)

            Button {
                place(message)
            } label: {
                HStack(spacing: MicaboSpacing.xs) {
                    Image(systemName: message.cardAdded ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text(i18n.t(message.cardAdded ? "ios.mika.chat.cardAdded" : "ios.mika.chat.addCard"))
                }
            }
            .buttonStyle(MicaboSecondaryButtonStyle(fullWidth: false))
            .disabled(message.cardAdded)
        }
        .padding(.top, 2)
    }

    private var thinkingRow: some View {
        HStack(spacing: 10) {
            MikaBlob(size: 24, wobble: 0.26, speed: 0.7)
                .accessibilityHidden(true)

            Text(i18n.t("ios.mika.chat.thinking"))
                .font(MicaboFont.ui(14, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(.top, 2)
    }

    private func failureRow(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.xs) {
            Text(message)
                .font(MicaboFont.caption)
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if chat.canRetry {
                Button(i18n.t("ios.retry")) {
                    Task { await chat.retry(level: level, language: language, using: aiService) }
                }
                .buttonStyle(MicaboSecondaryButtonStyle(fullWidth: false))
            }
        }
        .padding(.leading, 34)
    }

    private func noticeRow(_ text: String) -> some View {
        Text(text)
            .font(MicaboFont.ui(14, weight: .medium))
            .foregroundStyle(MicaboColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
    }

    // MARK: - Le champ

    private func composer(_ draft: Binding<String>) -> some View {
        VStack(spacing: 8) {
            if let attachment = chat.attachment {
                attachmentChip(attachment)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Menu {
                    Button {
                        showCoursePicker = true
                    } label: {
                        Label(i18n.t("ios.mika.chat.attachCourse"), systemImage: "books.vertical")
                    }

                    Button {
                        showDocumentSheet = true
                    } label: {
                        Label(i18n.t("ios.mika.chat.attachDocument"), systemImage: "doc.text")
                    }

                    if chat.attachment != nil {
                        Button(role: .destructive) {
                            chat.detach()
                        } label: {
                            Label(i18n.t("ios.mika.chat.detach"), systemImage: "xmark")
                        }
                    }
                } label: {
                    MicaboCircleIcon(systemImage: "paperclip", size: 40)
                }
                .accessibilityLabel(i18n.t("ios.mika.chat.attach"))

                TextField(i18n.t("ios.mika.chat.placeholder"), text: draft, axis: .vertical)
                    .lineLimit(1...5)
                    .font(MicaboFont.ui(16, weight: .regular))
                    .foregroundStyle(MicaboColor.ink)
                    .tint(MicaboColor.accent)
                    .focused($isComposing)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(MicaboColor.stroke, lineWidth: 1)
                    }

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MicaboColor.onInk)
                        .frame(width: 40, height: 40)
                        .background(canSend ? MicaboColor.ink : MicaboColor.inkTertiary, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .medium))
                .disabled(!canSend)
                .animation(OnboardingMotion.select, value: canSend)
                .accessibilityLabel(i18n.t("ios.mika.chat.send"))
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(MicaboColor.canvas)
    }

    private func attachmentChip(_ attachment: MikaAttachment) -> some View {
        HStack(spacing: 8) {
            if let emoji = attachment.emoji {
                Text(emoji)
                    .font(.system(size: 15))
            } else {
                Image(systemName: attachment.kind == .course ? "books.vertical" : "doc.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MicaboColor.accent)
            }

            Text(i18n.t("ios.mika.chat.attached", ["title": attachment.title]))
                .font(MicaboFont.ui(13, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                chat.detach()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
            .accessibilityLabel(i18n.t("ios.mika.chat.detach"))
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(MicaboColor.accentSoft, in: Capsule())
    }

    // MARK: - Les actions

    private var level: StudyLevel? {
        OnboardingPreferences.educationStage?.level
    }

    private var language: ContentLanguage {
        DeckSetup.defaultLanguage()
    }

    private func send() async {
        guard let gate = await chat.send(isPro: isPro, level: level, language: language, using: aiService) else { return }
        switch gate {
        case .allowed:
            // Posée **et répondue** : une panne n'est pas une question.
            guard chat.failure == nil else { return }
            Analytics.track(.mikaAsked, ["pro": .flag(isPro), "attached": .flag(chat.attachment != nil)])
        case .paywall:
            isComposing = false
            paywall = .mika
            Analytics.track(.mikaBlocked, ["reason": "paywall"])
        case .dailyCapReached:
            Haptics.warning()
            Analytics.track(.mikaBlocked, ["reason": "cap"])
        }
    }

    private func newConversation() {
        isComposing = false
        chat.reset()
        Haptics.light()
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
        }
    }

    /// Un cours de la bibliothèque devient la pièce jointe : son texte à plat, borné.
    private func attach(_ course: Course) {
        chat.attach(MikaAttachment(
            kind: .course,
            title: course.title,
            text: course.contextSnippet(limit: MikaLimits.attachmentCharacters),
            courseID: course.id,
            emoji: course.emoji
        ))
        Haptics.light()
    }

    /// Range la carte dans le cours joint ; sans cours joint, demande lequel.
    private func place(_ message: MikaMessage) {
        guard !message.cardAdded else { return }
        if let courseID = chat.attachment?.courseID, let course = course(with: courseID) {
            add(message, to: course)
        } else {
            cardToPlace = message
        }
    }

    private func add(_ message: MikaMessage, to course: Course) {
        guard let card = message.card, !message.cardAdded else { return }
        do {
            let inserted = try CourseRepository.addFlashcards([card], to: course, in: modelContext)
            guard !inserted.isEmpty else { return }
            chat.markCardAdded(message.id)
            Haptics.success()
            Analytics.track(.mikaCardAdded)
        } catch {
            // La carte reste proposée : un second appui réessaie.
        }
    }

    private func course(with id: UUID) -> Course? {
        var descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }
}
