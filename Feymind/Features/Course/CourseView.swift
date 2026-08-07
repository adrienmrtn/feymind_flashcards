import SwiftData
import SwiftUI

/// Lecture du contenu structuré d'un cours (accès secondaire).
/// Le parcours principal reste import → flashcards → entraînement.
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
                            CourseBlockView(
                                payload: payload,
                                accent: accent,
                                overlays: overlays(for: entity.id),
                                onAsk: { selection in
                                    askSelection = AskSelection(text: selection)
                                },
                                onHighlight: { range, color in
                                    addHighlight(blockId: entity.id, range: range, color: color)
                                },
                                onClearHighlights: { range in
                                    clearHighlights(blockId: entity.id, overlapping: range)
                                }
                            )
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
                        "Analyse du contenu",
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
                        Label("\(course.cards.count) cartes", systemImage: "rectangle.on.rectangle")
                        if !(course.highlights ?? []).isEmpty {
                            Label("\((course.highlights ?? []).count)", systemImage: "highlighter")
                        }
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
                Image(systemName: "highlighter")
                    .font(.system(size: 10, weight: .bold))
                Text("Sélectionnez un passage pour surligner ou demander à l'IA")
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
            Text("Passez aux flashcards pour mémoriser.")
                .font(FeyFont.caption)
                .foregroundStyle(FeyColor.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FeySpacing.lg)
    }

    // MARK: - Bouton flottant

    private var trainButton: some View {
        Button {
            Task { await openFlashcards() }
        } label: {
            HStack(spacing: FeySpacing.xs) {
                Image(systemName: course.cards.isEmpty ? "sparkles" : "rectangle.on.rectangle")
                Text(course.cards.isEmpty ? "Créer les flashcards" : "Voir les flashcards (\(course.cards.count))")
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
                    Task { await generateCards() }
                } label: {
                    Label("Générer d'autres cartes", systemImage: "sparkles")
                }

                if !(course.highlights ?? []).isEmpty {
                    Button {
                        clearAllHighlights()
                    } label: {
                        Label("Effacer tous les surlignages", systemImage: "eraser")
                    }
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

    // MARK: - Surlignage

    private func overlays(for blockId: UUID) -> [InlineMarkup.OverlayHighlight] {
        course.highlights(for: blockId).map {
            InlineMarkup.OverlayHighlight(start: $0.start, length: $0.length, color: $0.color)
        }
    }

    private func addHighlight(blockId: UUID, range: NSRange, color: HighlightColor) {
        guard range.length > 0 else { return }

        // On remplace les surlignages qui se chevauchent pour éviter les empilements.
        clearHighlights(blockId: blockId, overlapping: range, save: false)

        let highlight = TextHighlight(
            blockId: blockId,
            start: range.location,
            length: range.length,
            color: color,
            course: course
        )
        modelContext.insert(highlight)
        course.updatedAt = Date()
        try? modelContext.save()
    }

    private func clearHighlights(blockId: UUID, overlapping range: NSRange, save: Bool = true) {
        let victims = course.highlights(for: blockId).filter { $0.overlaps(range) }
        guard !victims.isEmpty else { return }
        for highlight in victims {
            modelContext.delete(highlight)
        }
        if save {
            course.updatedAt = Date()
            try? modelContext.save()
        }
    }

    private func clearAllHighlights() {
        for highlight in course.highlights ?? [] {
            modelContext.delete(highlight)
        }
        course.updatedAt = Date()
        try? modelContext.save()
    }

    // MARK: - Actions

    @MainActor
    private func openFlashcards() async {
        if course.cards.isEmpty {
            await generateCards()
            guard !course.cards.isEmpty else { return }
        }
        showFlashcards = true
    }

    @MainActor
    private func generateCards() async {
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
