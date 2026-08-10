import SwiftData
import SwiftUI

/// Écran principal d'un cours — calqué sur la maquette :
/// en-tête pastel plat (pas de grands arrondis), liste compacte de questions
/// avec pastille de statut, CTA « Commencer l'entraînement » en bas.
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

    private var heroTint: Color { Color(hexString: course.accentHex) }
    private var heroBackground: Color { heroTint.lightened(by: 0.82) }
    private var heroText: Color { heroTint.darkened(by: 0.28) }
    private var heroMuted: Color { heroTint.darkened(by: 0.05).opacity(0.85) }

    var body: some View {
        VStack(spacing: 0) {
            hero

            ScrollView {
                listContent
                    .padding(.horizontal, FeySpacing.screen)
                    .padding(.top, FeySpacing.md)
                    .padding(.bottom, cards.isEmpty ? FeySpacing.xxl : FeyLayout.bottomBarClearance)
            }
        }
        .feyScreenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .bottom) {
            if !cards.isEmpty {
                FeyBottomBar {
                    Button {
                        showStudy = true
                    } label: {
                        Text("Commencer l'entraînement")
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

    // MARK: - En-tête pastel plat

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                FeyCircleButton(
                    systemImage: "chevron.left",
                    style: .tinted(heroText),
                    size: 34,
                    accessibilityTitle: "Retour"
                ) {
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
                    FeyCircleIcon(systemImage: "ellipsis", style: .tinted(heroText), size: 34)
                }
                .accessibilityLabel("Actions du cours")
            }
            .padding(.bottom, FeySpacing.md)

            Text(course.title)
                .font(FeyFont.hanken(22, weight: .bold))
                .foregroundStyle(heroText)
                .tracking(FeyTracking.tight)
                .fixedSize(horizontal: false, vertical: true)

            if !course.summary.isEmpty {
                Text(course.summary)
                    .font(FeyFont.body)
                    .foregroundStyle(heroMuted)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !cards.isEmpty {
                HStack(spacing: 7) {
                    heroChip("\(cards.count) cartes")
                    if dueCount > 0 { heroChip("\(dueCount) dues") }
                    if let subject = course.subject?.nilIfBlank { heroChip(subject) }
                }
                .padding(.top, 14)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
    }

    private func heroChip(_ text: String) -> some View {
        Text(text)
            .font(FeyFont.micro)
            .foregroundStyle(heroText)
            .padding(.vertical, 6)
            .padding(.horizontal, 11)
            .background(Color.white.opacity(0.6), in: Capsule())
    }

    // MARK: - Liste

    @ViewBuilder
    private var listContent: some View {
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
            VStack(alignment: .leading, spacing: FeySpacing.sm) {
                HStack {
                    Text("Cartes")
                        .font(FeyFont.hanken(14, weight: .semibold))
                        .foregroundStyle(FeyColor.ink)
                    Spacer()
                    Text("\(cards.count)")
                        .font(FeyFont.hanken(12, weight: .medium))
                        .foregroundStyle(FeyColor.inkTertiary)
                }

                VStack(spacing: 0) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        Button {
                            editingCard = card
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                Text(card.front)
                                    .font(FeyFont.hanken(13, weight: .medium))
                                    .foregroundStyle(Color(hex: 0x2A2823))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Circle()
                                    .fill(statusColor(for: card))
                                    .frame(width: 8, height: 8)
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { editingCard = card } label: {
                                Label("Modifier", systemImage: "pencil")
                            }
                            Button(role: .destructive) { delete(card) } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }

                        if index < cards.count - 1 {
                            Rectangle()
                                .fill(FeyColor.stroke)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func statusColor(for card: Flashcard) -> Color {
        if card.isDue() {
            Color(hex: 0xC9B98A)
        } else if card.state == .new {
            FeyColor.inkTertiary.opacity(0.55)
        } else {
            Color(hex: 0x7FBF9A)
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
