import SwiftData
import SwiftUI

struct CourseView: View {
    @Bindable var course: Course

    @Environment(\.aiService) private var aiService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var askSelection: AskSelection?
    @State private var isGeneratingCards = false
    @State private var generationError: String?
    @State private var showFlashcards = false
    @State private var showDeleteConfirmation = false

    private var accent: Color { Color(hexString: course.accentHex) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FeySpacing.md) {
                    header

                    ForEach(course.orderedBlocks) { entity in
                        if let payload = entity.payload {
                            CourseBlockView(payload: payload, accent: accent) { selection in
                                askSelection = AskSelection(text: selection)
                            }
                        }
                    }

                    footerHint
                }
                .padding(.horizontal, FeySpacing.screen)
                .padding(.top, FeySpacing.xs)
                .padding(.bottom, 120)
            }
            .feyScreenBackground()

            trainButton
        }
        .navigationTitle(course.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(item: $askSelection) { selection in
            AskAISheet(course: course, selection: selection.text)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .navigationDestination(isPresented: $showFlashcards) {
            FlashcardsView(course: course)
        }
        .overlay {
            if isGeneratingCards {
                GenerationOverlay(
                    title: "Création des flashcards",
                    steps: [
                        "Relecture du cours",
                        "Sélection des notions à mémoriser",
                        "Rédaction des questions",
                        "Vérification des réponses"
                    ],
                    accent: accent
                )
            }
        }
        .alert("Génération impossible", isPresented: .constant(generationError != nil)) {
            Button("Fermer", role: .cancel) { generationError = nil }
        } message: {
            Text(generationError ?? "")
        }
        .confirmationDialog("Supprimer ce cours ?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                try? CourseRepository.delete(course, in: modelContext)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Le cours et ses \(course.cards.count) flashcards seront définitivement effacés.")
        }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            HStack(spacing: FeySpacing.xs) {
                Text(course.emoji)
                    .font(.system(size: 30))
                    .frame(width: 52, height: 52)
                    .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    if let subject = course.subject?.nilIfBlank {
                        FeyChip(text: subject, tint: accent)
                    }
                    HStack(spacing: FeySpacing.xs) {
                        Label("\(course.readingMinutes) min", systemImage: "clock")
                        Label("\(course.cards.count) cartes", systemImage: "rectangle.on.rectangle")
                    }
                    .font(FeyFont.micro)
                    .foregroundStyle(FeyColor.inkTertiary)
                }
                Spacer(minLength: 0)
            }

            Text(course.title)
                .font(FeyFont.screenTitle)
                .foregroundStyle(FeyColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !course.summary.isEmpty {
                Text(course.summary)
                    .font(FeyFont.body)
                    .foregroundStyle(FeyColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 10, weight: .bold))
                Text("Sélectionnez un passage pour demander à l'IA")
                    .font(FeyFont.micro)
            }
            .foregroundStyle(accent)
            .padding(.vertical, 7)
            .padding(.horizontal, 11)
            .background(accent.opacity(0.08), in: Capsule())

            Rectangle()
                .fill(FeyColor.stroke)
                .frame(height: 1)
                .padding(.top, FeySpacing.xxs)
        }
        .padding(.bottom, FeySpacing.xxs)
    }

    private var footerHint: some View {
        VStack(spacing: FeySpacing.xs) {
            Text("Fin du cours")
                .font(FeyFont.caption)
                .foregroundStyle(FeyColor.inkTertiary)
            Text("Passez à l'entraînement pour ancrer ces notions.")
                .font(FeyFont.caption)
                .foregroundStyle(FeyColor.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FeySpacing.lg)
    }

    // MARK: - Bouton flottant

    private var trainButton: some View {
        Button {
            Task { await startTraining() }
        } label: {
            HStack(spacing: FeySpacing.xs) {
                Image(systemName: course.cards.isEmpty ? "sparkles" : "bolt.fill")
                Text(course.cards.isEmpty ? "S'entraîner" : "S'entraîner (\(course.cards.count))")
            }
        }
        .buttonStyle(FeyPrimaryButtonStyle(tint: accent, fullWidth: false))
        .padding(.bottom, FeySpacing.lg)
        .shadow(color: FeyColor.canvas.opacity(0.9), radius: 18, x: 0, y: 0)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showFlashcards = true
                } label: {
                    Label("Voir les flashcards", systemImage: "rectangle.on.rectangle")
                }

                Button {
                    Task { await generateCards(replacing: false) }
                } label: {
                    Label("Générer d'autres cartes", systemImage: "sparkles")
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Supprimer le cours", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func startTraining() async {
        if course.cards.isEmpty {
            await generateCards(replacing: false)
            guard !course.cards.isEmpty else { return }
        }
        showFlashcards = true
    }

    @MainActor
    private func generateCards(replacing: Bool) async {
        guard !isGeneratingCards else { return }
        isGeneratingCards = true
        defer { isGeneratingCards = false }

        let request = FlashcardGenerationRequest(
            courseTitle: course.title,
            courseContext: course.contextSnippet(limit: 30_000),
            desiredCount: 12,
            existingFronts: course.cards.map(\.front)
        )

        do {
            let generated = try await aiService.generateFlashcards(request)
            try CourseRepository.addFlashcards(generated, to: course, in: modelContext)
        } catch {
            // Sans clé IA, on propose quand même un jeu de cartes construit localement.
            if shouldFallBackOffline(error) {
                let offline = OfflineCourseBuilder.buildFlashcards(
                    from: GeneratedCourse(
                        title: course.title,
                        summary: course.summary,
                        blocks: course.orderedBlocks.compactMap(\.payload)
                    ),
                    count: 10
                )
                try? CourseRepository.addFlashcards(offline, to: course, in: modelContext)
                generationError = (error as? LocalizedError)?.errorDescription
                    ?? "Cartes générées hors ligne : configurez l'IA pour un meilleur résultat."
            } else {
                generationError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func shouldFallBackOffline(_ error: Error) -> Bool {
        guard let serviceError = error as? AIServiceError else { return false }
        switch serviceError {
        case .notConfigured, .missingProviderKey, .network:
            return true
        default:
            return false
        }
    }
}

struct AskSelection: Identifiable {
    let id = UUID()
    let text: String
}
