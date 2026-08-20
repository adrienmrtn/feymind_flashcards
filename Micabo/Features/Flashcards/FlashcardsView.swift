import SwiftData
import SwiftUI

/// Écran principal d'un cours : une barre de retour posée sur le fond ivoire,
/// la vignette et le titre du cours, son résumé, puis la liste des questions
/// dans un bloc blanc. Le bouton de session, ancré en bas, porte le même nom
/// que sur l'onglet Réviser.
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
        VStack(spacing: 0) {
            navBar

            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    titleBlock
                    summaryCard
                    listContent
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, cards.isEmpty ? MicaboSpacing.xxl : MicaboLayout.bottomBarClearance)
            }
            .scrollIndicators(.hidden)
        }
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
                        showStudy = true
                    } label: {
                        Text(MicaboCopy.reviewButton(count: cards.count))
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
        .fullScreenCover(isPresented: $showStudy) {
            StudyView(source: .course(course))
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

    private var navBar: some View {
        HStack {
            MicaboCircleButton(systemImage: "chevron.left", size: 38, accessibilityTitle: "Retour") {
                dismiss()
            }

            Spacer()

            Menu {
                Button { isCreating = true } label: {
                    Label("Ajouter une carte", systemImage: "plus")
                }
                Button { Task { await generateMore() } } label: {
                    Label("Générer avec l'IA", systemImage: "sparkles")
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
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.vertical, MicaboSpacing.xs)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            MicaboTile.course(course, size: 56)

            Text(course.title)
                .font(MicaboFont.hanken(27, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(MicaboTracking.tight)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                if let subject = course.subject?.nilIfBlank {
                    MicaboBadge(text: subject, tone: .neutral)
                }
                if !cards.isEmpty {
                    MicaboBadge(text: "\(cards.count) carte\(cards.count > 1 ? "s" : "")", tone: .neutral)
                }
                if dueCount > 0 {
                    MicaboBadge(text: "\(dueCount) due\(dueCount > 1 ? "s" : "")", tone: .accent)
                }
            }
        }
        .padding(.top, MicaboSpacing.xxs)
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

                                Text(card.front)
                                    .font(MicaboFont.hanken(14, weight: .medium))
                                    .foregroundStyle(MicaboColor.ink)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)

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
