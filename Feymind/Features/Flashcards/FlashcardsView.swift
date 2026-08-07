import SwiftData
import SwiftUI

/// Écran principal d'un cours : les flashcards, modifiables, puis l'entraînement.
struct FlashcardsView: View {
    @Bindable var course: Course

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(\.dismiss) private var dismiss

    @State private var editingCard: Flashcard?
    @State private var isCreating = false
    @State private var isGenerating = false
    @State private var showStudy = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    private var cards: [Flashcard] { course.orderedCards }
    private var dueCount: Int { course.dueCards.count }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    CourseCover(course: course, emojiSize: 58)
                        .frame(height: 260)

                    panel
                        .offset(y: -28)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)

            headerButtons
        }
        .feyScreenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if !cards.isEmpty {
                FeyBottomBar {
                    Button {
                        showStudy = true
                    } label: {
                        HStack(spacing: FeySpacing.xs) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(dueCount > 0 ? "Commencer l'entraînement (\(dueCount))" : "Réviser en avance")
                        }
                    }
                    .buttonStyle(FeyPrimaryButtonStyle())
                }
            }
        }
        .sheet(item: $editingCard) { card in
            FlashcardEditorSheet(card: card)
        }
        .sheet(isPresented: $isCreating) {
            FlashcardCreatorSheet(course: course)
        }
        .fullScreenCover(isPresented: $showStudy) {
            StudyView(source: .course(course))
        }
        .overlay {
            if isGenerating {
                GenerationOverlay(
                    title: "Nouvelles flashcards",
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
            Text("Le cours et ses \(cards.count) flashcards seront définitivement effacés.")
        }
    }

    // MARK: - En-tête

    private var headerButtons: some View {
        HStack {
            FeyCircleButton(systemImage: "chevron.left", style: .glass, accessibilityTitle: "Retour") {
                dismiss()
            }

            Spacer()

            Menu {
                Button {
                    isCreating = true
                } label: {
                    Label("Ajouter une carte", systemImage: "plus")
                }

                Button {
                    Task { await generateMore() }
                } label: {
                    Label("Générer avec l'IA", systemImage: "sparkles")
                }

                if !cards.isEmpty {
                    Button {
                        resetProgress()
                    } label: {
                        Label("Réinitialiser la progression", systemImage: "arrow.counterclockwise")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Supprimer le cours", systemImage: "trash")
                }
            } label: {
                FeyCircleIcon(systemImage: "ellipsis", style: .glass)
            }
            .accessibilityLabel("Actions du cours")
        }
        .padding(.horizontal, FeySpacing.screen)
    }

    // MARK: - Contenu

    private var panel: some View {
        VStack(alignment: .leading, spacing: FeySpacing.md) {
            titleBlock

            if cards.isEmpty {
                FeyEmptyState(
                    systemImage: "rectangle.on.rectangle.angled",
                    title: "Aucune flashcard",
                    message: "Générez un jeu de cartes à partir du contenu importé, ou créez-en une à la main.",
                    actionTitle: "Générer avec l'IA"
                ) {
                    Task { await generateMore() }
                }
            } else {
                cardList
            }
        }
        .padding(.horizontal, FeySpacing.screen)
        .padding(.top, FeySpacing.lg)
        .padding(.bottom, cards.isEmpty ? FeySpacing.xxl : FeyLayout.bottomBarClearance)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            FeyColor.canvas,
            in: UnevenRoundedRectangle(
                topLeadingRadius: FeyRadius.xl,
                topTrailingRadius: FeyRadius.xl,
                style: .continuous
            )
        )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: FeySpacing.xs) {
            if let subject = course.subject?.nilIfBlank {
                FeyChip(text: subject)
            }

            Text(course.title)
                .font(FeyFont.screenTitle)
                .foregroundStyle(FeyColor.ink)
                .tracking(FeyTracking.tight)
                .fixedSize(horizontal: false, vertical: true)

            if !course.summary.isEmpty {
                Text(course.summary)
                    .font(FeyFont.body)
                    .foregroundStyle(FeyColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !cards.isEmpty {
                HStack(spacing: FeySpacing.xs) {
                    FeyChip(text: "\(cards.count) cartes")
                    if dueCount > 0 {
                        FeyChip(text: "\(dueCount) à réviser", tint: FeyColor.ink, filled: true)
                    }
                    if !course.newCards.isEmpty {
                        FeyChip(text: "\(course.newCards.count) nouvelles")
                    }
                }
                .padding(.top, FeySpacing.xxs)
            }
        }
    }

    private var cardList: some View {
        VStack(spacing: FeySpacing.sm) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                FlashcardRow(card: card, index: index + 1)
                    .onTapGesture { editingCard = card }
                    .contextMenu {
                        Button {
                            editingCard = card
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            delete(card)
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
            }
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
            existingFronts: course.cards.map(\.front)
        )

        do {
            let generated = try await aiService.generateFlashcards(request)
            try CourseRepository.addFlashcards(generated, to: course, in: modelContext)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Ligne de carte

struct FlashcardRow: View {
    let card: Flashcard
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: FeySpacing.xs) {
            HStack(alignment: .top, spacing: FeySpacing.sm) {
                Text("\(index)")
                    .font(FeyFont.micro)
                    .foregroundStyle(FeyColor.inkTertiary)
                    .frame(width: 18, alignment: .leading)
                    .padding(.top, 2)

                Text(card.front)
                    .font(FeyFont.bodyEmphasis)
                    .foregroundStyle(FeyColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: FeySpacing.xs)

                stateBadge
            }

            Text(card.back)
                .font(FeyFont.caption)
                .foregroundStyle(FeyColor.inkSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.leading, 30)
        }
        .feyCard(padding: FeySpacing.sm + 2, radius: FeyRadius.lg, elevated: false)
        .contentShape(Rectangle())
    }

    private var stateBadge: some View {
        Group {
            switch card.state {
            case .new:
                FeyChip(text: "Nouvelle")
            case .learning, .relearning:
                FeyChip(text: "En cours", tint: FeyColor.caution)
            case .review:
                if card.isDue() {
                    FeyChip(text: "À réviser", tint: FeyColor.ink, filled: true)
                } else {
                    FeyChip(text: dueLabel)
                }
            }
        }
    }

    private var dueLabel: String {
        "Dans " + SM2Scheduler.format(delay: card.dueDate.timeIntervalSinceNow)
    }
}
