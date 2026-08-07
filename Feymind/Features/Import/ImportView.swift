import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Écran d'import : texte collé ou PDF, puis génération des flashcards.
struct ImportView: View {
    let kind: ImportKind
    var onCreated: (Course) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var pastedText = ""
    @State private var extraction: PDFExtraction?
    @State private var analyzeVisuals = true
    @State private var showFileImporter = false

    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var offlineFallbackAvailable = false

    private var canGenerate: Bool {
        switch kind {
        case .text: pastedText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 40
        case .pdf: extraction != nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: FeySpacing.md) {
                        intro
                        titleField

                        switch kind {
                        case .text: textInput
                        case .pdf: pdfInput
                        }

                        aiNote
                    }
                    .padding(.horizontal, FeySpacing.screen)
                    .padding(.top, FeySpacing.xs)
                    .padding(.bottom, 120)
                }
                .feyScreenBackground()
                .scrollDismissesKeyboard(.interactively)

                FeyBottomBar {
                    Button {
                        Task { await generate(offline: false) }
                    } label: {
                        HStack(spacing: FeySpacing.xs) {
                            Image(systemName: "sparkles")
                            Text("Générer les flashcards")
                        }
                    }
                    .buttonStyle(FeyPrimaryButtonStyle(tint: canGenerate ? FeyColor.accent : FeyColor.inkTertiary))
                    .disabled(!canGenerate || isGenerating)
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(FeyColor.inkSecondary)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .overlay {
                if isGenerating {
                    GenerationOverlay(
                        title: "Création des flashcards",
                        steps: [
                            kind == .pdf ? "Lecture du document" : "Lecture de vos notes",
                            "Repérage des notions clés",
                            "Rédaction des questions",
                            "Vérification des réponses"
                        ]
                    )
                }
            }
            .alert("Génération impossible", isPresented: .constant(errorMessage != nil)) {
                if offlineFallbackAvailable {
                    Button("Créer sans IA") {
                        errorMessage = nil
                        Task { await generate(offline: true) }
                    }
                }
                Button("Fermer", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(isGenerating)
    }

    // MARK: - Sections

    private var intro: some View {
        HStack(alignment: .top, spacing: FeySpacing.sm) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(kind.tint)
                .frame(width: 40, height: 40)
                .background(kind.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous))

            Text(kind == .pdf
                 ? "Feymind lit le PDF et en tire un jeu de flashcards prêt à réviser."
                 : "Collez vos notes, même brutes. Feymind en fait des flashcards.")
                .font(FeyFont.body)
                .foregroundStyle(FeyColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Titre")
                .font(FeyFont.caption)
                .foregroundStyle(FeyColor.ink)

            TextField("Facultatif, l'IA en proposera un", text: $title)
                .font(FeyFont.body)
                .padding(FeySpacing.sm)
                .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous)
                        .strokeBorder(FeyColor.stroke, lineWidth: 1)
                }
        }
    }

    private var textInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Contenu")
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.ink)
                Spacer()
                Text("\(pastedText.count) caractères")
                    .font(FeyFont.micro)
                    .foregroundStyle(FeyColor.inkTertiary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $pastedText)
                    .font(FeyFont.body)
                    .scrollContentBackground(.hidden)
                    .padding(FeySpacing.sm)
                    .frame(minHeight: 260, alignment: .topLeading)

                if pastedText.isEmpty {
                    Text("Collez ici votre chapitre, vos notes de cours ou un article.")
                        .font(FeyFont.body)
                        .foregroundStyle(FeyColor.inkTertiary)
                        .padding(FeySpacing.sm + 4)
                        .allowsHitTesting(false)
                }
            }
            .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous)
                    .strokeBorder(FeyColor.stroke, lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var pdfInput: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            if let extraction {
                VStack(alignment: .leading, spacing: FeySpacing.sm) {
                    HStack(spacing: FeySpacing.sm) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(FeyColor.accent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(extraction.fileName)
                                .font(FeyFont.cardTitle)
                                .foregroundStyle(FeyColor.ink)
                                .lineLimit(1)
                            Text("\(extraction.pageCount) pages, \(extraction.text.count) caractères lus")
                                .font(FeyFont.micro)
                                .foregroundStyle(FeyColor.inkTertiary)
                        }

                        Spacer(minLength: 0)

                        Button("Changer") { showFileImporter = true }
                            .buttonStyle(FeyQuietButtonStyle())
                    }

                    if !extraction.hasUsableText {
                        Label(
                            "Peu de texte détecté : Feymind s'appuiera surtout sur les images des pages.",
                            systemImage: "eye"
                        )
                        .font(FeyFont.caption)
                        .foregroundStyle(FeyColor.amber)
                    }
                }
                .feyCard(padding: FeySpacing.sm + 2, radius: FeyRadius.lg, elevated: false)
            } else {
                Button {
                    showFileImporter = true
                } label: {
                    VStack(spacing: FeySpacing.xs) {
                        Image(systemName: "arrow.up.doc.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(FeyColor.accent)
                        Text("Choisir un PDF")
                            .font(FeyFont.cardTitle)
                            .foregroundStyle(FeyColor.ink)
                        Text("Jusqu'à quelques centaines de pages")
                            .font(FeyFont.caption)
                            .foregroundStyle(FeyColor.inkTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FeySpacing.xl)
                    .background(FeyColor.accentSoft, in: RoundedRectangle(cornerRadius: FeyRadius.lg, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: FeyRadius.lg, style: .continuous)
                            .strokeBorder(FeyColor.accentTint, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    }
                }
                .buttonStyle(.plain)
            }

            Toggle(isOn: $analyzeVisuals) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Analyser les schémas et images")
                        .font(FeyFont.body)
                        .foregroundStyle(FeyColor.ink)
                    Text("Quelques pages sont envoyées au modèle de vision.")
                        .font(FeyFont.micro)
                        .foregroundStyle(FeyColor.inkTertiary)
                }
            }
            .tint(FeyColor.accent)
        }
    }

    private var aiNote: some View {
        HStack(spacing: FeySpacing.xs) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
            Text("Le traitement passe par vos Edge Functions Supabase. Modèle : \(AppConfig.aiModel).")
                .font(FeyFont.micro)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(FeyColor.inkTertiary)
        .padding(.top, FeySpacing.xxs)
    }

    // MARK: - Fichiers

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
            return
        }

        Task {
            do {
                // Les pages sont toujours rendues : le réglage décide seulement de leur envoi.
                let parsed = try PDFImportService.extract(from: url)
                await MainActor.run {
                    extraction = parsed
                    if title.isEmpty { title = parsed.fileName }
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    offlineFallbackAvailable = false
                }
            }
        }
    }

    // MARK: - Génération

    @MainActor
    private func generate(offline: Bool) async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }

        let rawText: String
        let images: [Data]
        let fileName: String?

        switch kind {
        case .text:
            rawText = pastedText
            images = []
            fileName = nil
        case .pdf:
            guard let extraction else { return }
            rawText = extraction.text
            images = analyzeVisuals ? extraction.pageImages : []
            fileName = extraction.fileName
        }

        let request = CourseGenerationRequest(
            rawText: rawText,
            pageImages: images,
            hintTitle: title.nilIfBlank,
            sourceName: fileName
        )

        do {
            let generated: GeneratedCourse
            if offline {
                generated = OfflineCourseBuilder.build(
                    from: rawText,
                    hintTitle: title.nilIfBlank,
                    sourceName: fileName
                )
            } else {
                generated = try await aiService.generateCourse(request)
            }

            let course = try CourseRepository.save(
                generated,
                source: kind == .pdf ? .pdf : .text,
                rawText: rawText,
                fileName: fileName,
                in: modelContext
            )

            let cards: [GeneratedFlashcard]
            if offline {
                cards = OfflineCourseBuilder.buildFlashcards(from: generated, count: 12)
            } else {
                do {
                    cards = try await aiService.generateFlashcards(
                        FlashcardGenerationRequest(
                            courseTitle: course.title,
                            courseContext: course.contextSnippet(limit: 30_000),
                            desiredCount: 12,
                            existingFronts: []
                        )
                    )
                } catch {
                    // Les flashcards sont le produit principal : repli hors ligne plutôt qu'un cours vide.
                    if isRecoverable(error) {
                        cards = OfflineCourseBuilder.buildFlashcards(from: generated, count: 12)
                    } else {
                        throw error
                    }
                }
            }

            try CourseRepository.addFlashcards(cards, to: course, in: modelContext)
            onCreated(course)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            offlineFallbackAvailable = isRecoverable(error)
        }
    }

    private func isRecoverable(_ error: Error) -> Bool {
        guard let serviceError = error as? AIServiceError else { return false }
        switch serviceError {
        case .notConfigured, .missingProviderKey, .network, .server, .invalidResponse:
            return true
        case .emptySource:
            return false
        }
    }
}
