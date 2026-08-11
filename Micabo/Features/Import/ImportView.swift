import SwiftData
import SwiftUI
import UIKit
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
                    VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                        intro
                        titleField

                        switch kind {
                        case .text: textInput
                        case .pdf: pdfInput
                        }

                        aiNote
                    }
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.top, MicaboSpacing.xs)
                    .padding(.bottom, MicaboLayout.bottomBarClearance)
                }
                .micaboScreenBackground()
                .scrollDismissesKeyboard(.interactively)

                MicaboBottomBar {
                    Button {
                        Task { await generate(offline: false) }
                    } label: {
                        HStack(spacing: MicaboSpacing.xs) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Générer les flashcards")
                        }
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle(tint: canGenerate ? MicaboColor.ink : MicaboColor.strokeStrong))
                    .disabled(!canGenerate || isGenerating)
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(MicaboColor.accent)
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
        Text(kind == .pdf
             ? "Micabo lit le PDF, observe les figures et en tire un jeu de flashcards prêt à réviser."
             : "Collez vos notes, même brutes. Micabo en fait des flashcards.")
            .font(MicaboFont.body)
            .foregroundStyle(MicaboColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Titre")
                .font(MicaboFont.captionEmphasis)
                .foregroundStyle(MicaboColor.ink)

            TextField("Facultatif, l'IA en proposera un", text: $title)
                .font(MicaboFont.body)
                .padding(MicaboSpacing.sm)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        }
    }

    private var textInput: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Contenu")
                    .font(MicaboFont.captionEmphasis)
                    .foregroundStyle(MicaboColor.ink)
                Spacer()
                Text("\(pastedText.count) caractères")
                    .font(MicaboFont.micro)
                    .foregroundStyle(MicaboColor.inkTertiary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $pastedText)
                    .font(MicaboFont.body)
                    .scrollContentBackground(.hidden)
                    .padding(MicaboSpacing.sm)
                    .frame(minHeight: 260, alignment: .topLeading)

                if pastedText.isEmpty {
                    Text("Collez ici votre chapitre, vos notes de cours ou un article.")
                        .font(MicaboFont.body)
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .padding(MicaboSpacing.sm + 4)
                        .allowsHitTesting(false)
                }
            }
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        }
    }

    @ViewBuilder
    private var pdfInput: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            if let extraction {
                VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
                    HStack(spacing: MicaboSpacing.sm) {
                        coverPreview(extraction)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(extraction.fileName)
                                .font(MicaboFont.cardTitle)
                                .foregroundStyle(MicaboColor.ink)
                                .lineLimit(2)
                            Text("\(extraction.pageCount) pages, \(extraction.text.count) caractères lus")
                                .font(MicaboFont.micro)
                                .foregroundStyle(MicaboColor.inkTertiary)
                        }

                        Spacer(minLength: 0)

                        Button("Changer") { showFileImporter = true }
                            .buttonStyle(MicaboQuietButtonStyle())
                    }

                    if !extraction.hasUsableText {
                        Label(
                            "Peu de texte détecté : Micabo s'appuiera surtout sur les images des pages.",
                            systemImage: "eye"
                        )
                        .font(MicaboFont.caption)
                        .foregroundStyle(MicaboColor.caution)
                    }
                }
                .micaboCard(padding: MicaboSpacing.sm + 2, radius: MicaboRadius.lg, elevated: false)
            } else {
                Button {
                    showFileImporter = true
                } label: {
                    VStack(spacing: MicaboSpacing.sm) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color(hex: 0x47665A))
                            .frame(width: 52, height: 52)
                            .background(Color(hex: 0xE4ECE6), in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
                        Text("Choisir un PDF")
                            .font(MicaboFont.cardTitle)
                            .foregroundStyle(MicaboColor.ink)
                        Text("Jusqu'à quelques centaines de pages")
                            .font(MicaboFont.caption)
                            .foregroundStyle(MicaboColor.inkTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MicaboSpacing.xl)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous)
                            .strokeBorder(MicaboColor.strokeStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    }
                }
                .buttonStyle(.plain)
            }

            Toggle(isOn: $analyzeVisuals) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Analyser les schémas et images")
                        .font(MicaboFont.body)
                        .foregroundStyle(MicaboColor.ink)
                    Text("Quelques pages sont envoyées au modèle de vision.")
                        .font(MicaboFont.micro)
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
            }
            .tint(MicaboColor.accent)
            .padding(.horizontal, MicaboSpacing.xxs)
        }
    }

    @ViewBuilder
    private func coverPreview(_ extraction: PDFExtraction) -> some View {
        if let data = extraction.coverImage, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
        } else {
            Image(systemName: "doc")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .frame(width: 44, height: 56)
                .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
        }
    }

    private var aiNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock")
                .font(.system(size: 10, weight: .semibold))
            Text("Le traitement passe par vos Edge Functions Supabase. Modèle : \(AppConfig.aiModel).")
                .font(MicaboFont.micro)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(MicaboColor.inkTertiary)
        .padding(.top, MicaboSpacing.xxs)
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
        let cover: Data?

        switch kind {
        case .text:
            rawText = pastedText
            images = []
            fileName = nil
            cover = nil
        case .pdf:
            guard let extraction else { return }
            rawText = extraction.text
            images = analyzeVisuals ? extraction.pageImages : []
            fileName = extraction.fileName
            cover = extraction.coverImage
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
                coverImageData: cover,
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
