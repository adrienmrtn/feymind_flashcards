import SwiftData
import SwiftUI

/// **Les cartes d'un cours.**
///
/// Cet écran vient un cran après la fiche, qui est l'écran du cours : on y arrive parce
/// qu'on a demandé des cartes, et il ne parle donc que d'elles. Le résumé et le contenu du
/// cours n'y sont pas répétés, ils sont juste derrière, dans la fiche.
///
/// Il porte le même en-tête que tous les autres écrans, la seule couleur propre au cours
/// étant sa tuile ; le bouton de session, ancré en bas, porte le nom qu'il a partout.
struct FlashcardsView: View {
    @Bindable var course: Course

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(\.dismiss) private var dismiss
    @Environment(ProAccess.self) private var pro: ProAccess?

    @State private var editingCard: Flashcard?
    @State private var isCreating = false
    @State private var isMasking = false
    @State private var isGenerating = false
    @State private var showCardOptions = false
    @State private var showStudy = false
    @State private var studyMode: StudyMode = .scheduled
    @State private var errorMessage: String?
    @State private var paywall: PaywallTrigger?

    private var cards: [Flashcard] { course.orderedCards }
    private var dueCount: Int { course.dueCards.count }
    private var canPractice: Bool { pro?.canPractice ?? true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                header
                listContent
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xs)
            .padding(.bottom, cards.isEmpty ? MicaboSpacing.xxl : MicaboLayout.bottomBarClearance)
        }
        .scrollIndicators(.hidden)
        .micaboScreenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .enablesSwipeBack()
        .overlay(alignment: .bottom) {
            if !cards.isEmpty {
                MicaboBottomBar {
                    Button(action: startSession) {
                        HStack(spacing: MicaboSpacing.xs) {
                            Text(dueCount > 0 ? MicaboCopy.reviewButton(count: dueCount) : "Entraînement libre")

                            if dueCount == 0, !canPractice {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle())
                }
            }
        }
        .sheet(item: $editingCard) { card in
            FlashcardEditorSheet(card: card)
        }
        .sheet(isPresented: $isCreating) {
            FlashcardCreatorSheet(course: course)
        }
        .sheet(isPresented: $isMasking) {
            OcclusionEditorSheet(course: course)
        }
        .sheet(isPresented: $showCardOptions) {
            GenerateCardsSheet(course: course) { options in
                Task { await generateMore(options) }
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .fullScreenCover(isPresented: $showStudy) {
            StudyView(source: .course(course), mode: studyMode)
        }
        .micaboPaywall($paywall)
        .overlay {
            if isGenerating {
                GenerationOverlay(
                    title: "Nouvelles cartes",
                    steps: ["Relecture de la fiche", "Choix des notions", "Rédaction", "Vérification"]
                )
            }
        }
        .alert("Oups", isPresented: .constant(errorMessage != nil)) {
            Button("Fermer", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            MicaboScreenHeader(
                title: course.title,
                eyebrow: headerEyebrow,
                tile: MicaboTile.course(course, size: 52),
                back: MicaboHeaderBack.back { dismiss() }
            ) {
                courseMenu
            }

            if dueCount > 0 {
                MicaboBadge(text: "\(dueCount) à réviser", tone: .accent)
            }
        }
        .padding(.top, MicaboSpacing.xs)
    }

    /// Le titre de l'écran est le cours, le sur-titre dit qu'on est dans ses cartes : sans
    /// ça, deux écrans du même cours porteraient exactement le même en-tête.
    private var headerEyebrow: String {
        let volume = MicaboCopy.cards(cards.count)
        guard let subject = course.subject?.nilIfBlank else { return volume }
        return "\(subject) · \(volume)"
    }

    private var courseMenu: some View {
        Menu {
            if !cards.isEmpty {
                Button(action: startPractice) {
                    Label("Entraînement libre", systemImage: canPractice ? "dumbbell" : "lock.fill")
                }
            }
            Button { isCreating = true } label: {
                Label("Ajouter une carte", systemImage: "plus")
            }
            Button { isMasking = true } label: {
                Label("Masquer un schéma", systemImage: "rectangle.dashed")
            }
            if canGenerate {
                Button { showCardOptions = true } label: {
                    Label("Générer avec l'IA", systemImage: "sparkles")
                }
            }
            if canAddReverseCards {
                Button { addReverseCards() } label: {
                    Label("Ajouter les cartes inverses", systemImage: "arrow.left.arrow.right")
                }
            }
            if !cards.isEmpty {
                Button { resetProgress() } label: {
                    Label("Réinitialiser la progression", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            MicaboCircleIcon(systemImage: "ellipsis", size: 38)
        }
        .accessibilityLabel("Actions des cartes")
    }

    // MARK: - Session

    /// Réviser ce qui est dû reste gratuit ; l'entraînement libre demande un abonnement.
    ///
    /// Sans carte due, une vraie session serait vide : le bouton annonce l'entraînement
    /// libre au lieu de promettre une révision, et il porte son cadenas.
    private func startSession() {
        guard dueCount > 0 else {
            startPractice()
            return
        }
        studyMode = .scheduled
        showStudy = true
    }

    private func startPractice() {
        guard canPractice else {
            paywall = .practice
            return
        }
        studyMode = .practice
        showStudy = true
    }

    // MARK: - Liste

    /// Vrai quand le modèle a de quoi écrire : la fiche d'un cours, ou le texte collé dans un
    /// paquet. Un paquet nu n'a rien à relire, et proposer de générer n'y mènerait qu'à une
    /// erreur.
    private var canGenerate: Bool {
        course.contextText.nilIfBlank != nil || course.rawText.nilIfBlank != nil
    }

    @ViewBuilder
    private var listContent: some View {
        if cards.isEmpty {
            MicaboEmptyState(
                systemImage: "rectangle.on.rectangle.angled",
                title: "Aucune carte",
                message: emptyMessage,
                actionTitle: canGenerate ? MicaboCopy.cardsButton : "Écrire une carte"
            ) {
                if canGenerate {
                    showCardOptions = true
                } else {
                    isCreating = true
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(text: "Cartes · \(cards.count)")

                VStack(spacing: 0) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        Button {
                            editingCard = card
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                Circle()
                                    .fill(statusColor(for: card))
                                    .frame(width: 8, height: 8)

                                // Le recto d'une occlusion est toujours le même : dans une
                                // liste, c'est le nom de la zone qui distingue les cartes.
                                Text(FormulaRenderer.stripped(card.isOcclusion ? card.back : card.front))
                                    .font(MicaboFont.hanken(14, weight: .medium))
                                    .foregroundStyle(MicaboColor.ink)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(badges(for: card), id: \.self) { badge in
                                    Image(systemName: badge)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(MicaboColor.accent)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(MicaboColor.inkTertiary.opacity(0.7))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, MicaboSpacing.md)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(MicaboRowButtonStyle())
                        .contextMenu {
                            Button { editingCard = card } label: {
                                Label("Modifier", systemImage: "pencil")
                            }
                            Button(role: .destructive) { delete(card) } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }

                        if index < cards.count - 1 {
                            MicaboHairline(inset: 36)
                        }
                    }
                }
                .micaboGroup()
            }
        }
    }

    private var emptyMessage: String {
        guard canGenerate else {
            return "Ce paquet est nu. Écris ta première carte : un recto, un verso, et elle entre dans ta file du jour."
        }
        return course.source == .deck
            ? "Micabo peut en écrire à partir du texte du paquet, et tu peux aussi en créer une à la main."
            : "Micabo peut en écrire à partir de la fiche du cours, et tu peux aussi en créer une à la main."
    }

    /// Ce que la rangée signale d'un coup d'œil : format, son, sens inverse.
    private func badges(for card: Flashcard) -> [String] {
        var symbols: [String] = []
        if let format = card.format.badgeSystemImage { symbols.append(format) }
        if card.hasAudio { symbols.append("speaker.wave.2") }
        if card.isReversed { symbols.append("arrow.left.arrow.right") }
        return symbols
    }

    /// Proposé dès qu'une carte n'a pas encore son sens inverse.
    private var canAddReverseCards: Bool {
        let reversedGroups = Set(cards.filter(\.isReversed).compactMap(\.groupID))
        return cards.contains { card in
            guard !card.isReversed, card.kind == .basic else { return false }
            guard let group = card.groupID else { return true }
            return !reversedGroups.contains(group)
        }
    }

    private func addReverseCards() {
        withAnimation {
            try? CourseRepository.addReverseCards(for: course, in: modelContext)
        }
        Haptics.success()
    }

    private func statusColor(for card: Flashcard) -> Color {
        if card.isDue() {
            MicaboColor.caution
        } else if card.state == .new {
            MicaboColor.inkTertiary.opacity(0.5)
        } else {
            MicaboColor.positive
        }
    }

    // MARK: - Actions

    private func delete(_ card: Flashcard) {
        withAnimation {
            try? CourseRepository.delete(card, in: modelContext)
        }
    }

    private func resetProgress() {
        withAnimation {
            course.cards.forEach { $0.resetScheduling() }
            try? modelContext.save()
        }
    }

    @MainActor
    private func generateMore(_ options: CardGeneration.Options) async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        do {
            try await CardGeneration.run(for: course, options: options, using: aiService, in: modelContext)
            Haptics.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
