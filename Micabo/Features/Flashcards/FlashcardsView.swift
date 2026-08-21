import SwiftData
import SwiftUI

/// Écran principal d'un cours. Il porte le même en-tête que tous les autres écrans —
/// crème, sur-titre puis grand titre — la seule couleur propre au cours étant sa tuile.
/// Suivent le résumé et la liste des questions dans un bloc blanc ; le bouton de
/// session, ancré en bas, porte le même nom que sur l'onglet Réviser.
struct FlashcardsView: View {
    @Bindable var course: Course

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(\.dismiss) private var dismiss

    @State private var editingCard: Flashcard?
    @State private var isCreating = false
    @State private var isMasking = false
    @State private var isGenerating = false
    @State private var showStudy = false
    @State private var studyMode: StudyMode = .scheduled
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    private var cards: [Flashcard] { course.orderedCards }
    private var dueCount: Int { course.dueCards.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                header
                summaryCard
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
                    Button {
                        Haptics.medium()
                        // Sans carte due, une vraie session serait vide : on annonce
                        // l'entraînement libre au lieu de promettre une révision.
                        studyMode = dueCount > 0 ? .scheduled : .practice
                        showStudy = true
                    } label: {
                        Text(dueCount > 0 ? MicaboCopy.reviewButton(count: dueCount) : "Entraînement libre")
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
        .fullScreenCover(isPresented: $showStudy) {
            StudyView(source: .course(course), mode: studyMode)
        }
        .overlay {
            if isGenerating {
                GenerationOverlay(
                    title: "Nouvelles cartes",
                    steps: ["Relecture du contenu", "Choix des notions", "Rédaction", "Vérification"]
                )
            }
        }
        .alert("Oups", isPresented: .constant(errorMessage != nil)) {
            Button("Fermer", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("Supprimer ce cours ?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                try? CourseRepository.delete(course, in: modelContext)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Le cours et ses \(MicaboCopy.cards(cards.count)) seront définitivement effacés.")
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

    /// Matière et volume dans le sur-titre : c'est la place de ce genre d'information,
    /// et le cours n'a donc pas besoin d'un bandeau à lui.
    private var headerEyebrow: String {
        let volume = MicaboCopy.cards(cards.count)
        guard let subject = course.subject?.nilIfBlank else { return volume }
        return "\(subject) · \(volume)"
    }

    private var courseMenu: some View {
        Menu {
            if !cards.isEmpty {
                Button {
                    studyMode = .practice
                    showStudy = true
                } label: {
                    Label("Entraînement libre", systemImage: "dumbbell")
                }
            }
            Button { isCreating = true } label: {
                Label("Ajouter une carte", systemImage: "plus")
            }
            Button { isMasking = true } label: {
                Label("Masquer un schéma", systemImage: "rectangle.dashed")
            }
            Button { Task { await generateMore() } } label: {
                Label("Générer avec l'IA", systemImage: "sparkles")
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
            Divider()
            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                Label("Supprimer le cours", systemImage: "trash")
            }
        } label: {
            MicaboCircleIcon(systemImage: "ellipsis", size: 38)
        }
        .accessibilityLabel("Actions du cours")
    }

    // MARK: - Liste

    @ViewBuilder
    private var listContent: some View {
        if cards.isEmpty {
            MicaboEmptyState(
                systemImage: "rectangle.on.rectangle.angled",
                title: "Aucune carte",
                message: "Génère un jeu de cartes à partir du contenu importé, ou crée-en une à la main.",
                actionTitle: "Générer avec l'IA"
            ) {
                Task { await generateMore() }
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

    /// Le résumé vit sous le titre, dans une surface blanche à part.
    @ViewBuilder
    private var summaryCard: some View {
        if let summary = course.summary.nilIfBlank {
            Text(summary)
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .micaboGroup()
        }
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
    private func generateMore() async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        let request = FlashcardGenerationRequest(
            courseTitle: course.title,
            courseContext: course.contextSnippet(limit: 30_000),
            desiredCount: 10,
            existingFronts: course.cards.map(\.front),
            mix: QuestionMixPreferences.current
        )

        do {
            let generated = try await aiService.generateFlashcards(request)
            try CourseRepository.addFlashcards(generated, to: course, in: modelContext)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
