import SwiftData
import SwiftUI

/// Page « flashcards créées » : relecture, modification, ajout, suppression, puis entraînement.
struct FlashcardsView: View {
    @Bindable var course: Course

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService

    @State private var editingCard: Flashcard?
    @State private var isCreating = false
    @State private var isGenerating = false
    @State private var showStudy = false
    @State private var errorMessage: String?

    private var accent: Color { Color(hexString: course.accentHex) }

    private var cards: [Flashcard] {
        course.cards.sorted { $0.position < $1.position }
    }

    private var dueCount: Int {
        course.dueCards.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content
            if !cards.isEmpty {
                FeyBottomBar {
                    Button {
                        showStudy = true
                    } label: {
                        HStack(spacing: FeySpacing.xs) {
                            Image(systemName: "play.fill")
                            Text(dueCount > 0 ? "Commencer l'entraînement (\(dueCount))" : "Réviser en avance")
                        }
                    }
                    .buttonStyle(FeyPrimaryButtonStyle(tint: accent))
                }
            }
        }
        .feyScreenBackground()
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
                        Divider()
                        Button {
                            resetProgress()
                        } label: {
                            Label("Réinitialiser la progression", systemImage: "arrow.counterclockwise")
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(accent)
                }
            }
        }
        .sheet(item: $editingCard) { card in
            FlashcardEditorSheet(card: card, accent: accent)
        }
        .sheet(isPresented: $isCreating) {
            FlashcardCreatorSheet(course: course, accent: accent)
        }
        .fullScreenCover(isPresented: $showStudy) {
            StudyView(source: .course(course))
        }
        .overlay {
            if isGenerating {
                GenerationOverlay(
                    title: "Nouvelles flashcards",
                    steps: ["Relecture du cours", "Choix des notions", "Rédaction", "Vérification"],
                    accent: accent
                )
            }
        }
        .alert("Oups", isPresented: .constant(errorMessage != nil)) {
            Button("Fermer", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if cards.isEmpty {
            ScrollView {
                FeyEmptyState(
                    systemImage: "rectangle.on.rectangle.angled",
                    title: "Aucune flashcard",
                    message: "Générez un jeu de cartes à partir du cours, ou créez-en une à la main.",
                    actionTitle: "Générer avec l'IA"
                ) {
                    Task { await generateMore() }
                }
                .padding(.top, FeySpacing.xxl)
            }
        } else {
            ScrollView {
                VStack(spacing: FeySpacing.sm) {
                    summaryBar

                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        FlashcardRow(card: card, index: index + 1, accent: accent)
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
                .padding(.horizontal, FeySpacing.screen)
                .padding(.top, FeySpacing.xs)
                .padding(.bottom, 110)
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: FeySpacing.sm) {
            statPill(value: cards.count, label: "cartes", tint: FeyColor.inkSecondary)
            statPill(value: dueCount, label: "à réviser", tint: accent)
            statPill(value: cards.filter { $0.state == .new }.count, label: "nouvelles", tint: FeyColor.mint)
            Spacer(minLength: 0)
        }
        .padding(.bottom, FeySpacing.xxs)
    }

    private func statPill(value: Int, label: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(FeyFont.caption)
                .foregroundStyle(tint)
            Text(label)
                .font(FeyFont.micro)
                .foregroundStyle(FeyColor.inkTertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(FeyColor.surfaceMuted, in: Capsule())
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
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: FeySpacing.xs) {
            HStack(alignment: .top, spacing: FeySpacing.xs) {
                Text("\(index)")
                    .font(FeyFont.micro)
                    .foregroundStyle(FeyColor.inkTertiary)
                    .frame(width: 22, alignment: .leading)
                    .padding(.top, 2)

                Text(card.front)
                    .font(FeyFont.bodyEmphasis)
                    .foregroundStyle(FeyColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: FeySpacing.xs)

                stateBadge
            }

            HStack(alignment: .top, spacing: FeySpacing.xs) {
                Rectangle()
                    .fill(FeyColor.stroke)
                    .frame(width: 1)
                    .padding(.leading, 10)

                Text(card.back)
                    .font(.system(size: 15))
                    .foregroundStyle(FeyColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 0)
        }
        .feyCard(padding: FeySpacing.sm + 2, radius: FeyRadius.md, elevated: false)
        .contentShape(Rectangle())
    }

    private var stateBadge: some View {
        Group {
            switch card.state {
            case .new:
                FeyChip(text: "Nouvelle", tint: FeyColor.mint)
            case .learning, .relearning:
                FeyChip(text: "En cours", tint: FeyColor.amber)
            case .review:
                FeyChip(text: dueLabel, tint: card.isDue() ? accent : FeyColor.inkTertiary)
            }
        }
    }

    private var dueLabel: String {
        if card.isDue() { return "À réviser" }
        let delay = card.dueDate.timeIntervalSinceNow
        return "Dans " + SM2Scheduler.format(delay: delay)
    }
}
