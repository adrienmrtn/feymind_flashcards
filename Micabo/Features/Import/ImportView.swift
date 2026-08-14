import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

/// Écran d'import : texte, PDF, photos/scan ou Word, puis génération des flashcards.
struct ImportView: View {
    let kind: ImportKind
    var onCreated: (Course) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var pastedText = ""
    @State private var imported: ImportedDocument?
    @State private var analyzeVisuals = false
    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var showScanner = false
    @State private var photoItems: [PhotosPickerItem] = []

    @State private var isReading = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var offlineFallbackAvailable = false

    private var canGenerate: Bool {
        switch kind {
        case .text:
            pastedText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 40
        case .pdf, .photo, .docx:
            imported != nil
        }
    }

    private var showsVisionToggle: Bool {
        kind == .pdf || kind == .photo
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
                        case .pdf, .docx: fileInput
                        case .photo: photoInput
                        }

                        if showsVisionToggle {
                            visionToggle
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
                    .disabled(!canGenerate || isGenerating || isReading)
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
                allowedContentTypes: kind == .docx ? [UTType.docx] : [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $photoItems,
                maxSelectionCount: OnDeviceOCR.pageLimit,
                matching: .images
            )
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await loadPhotos(items) }
            }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentCameraView { images in
                    showScanner = false
                    Task { await ingestPhotos(images) }
                } onCancel: {
                    showScanner = false
                }
                .ignoresSafeArea()
            }
            .overlay {
                if isReading {
                    GenerationOverlay(
                        title: "Lecture des pages",
                        steps: [
                            "Préparation des images",
                            "OCR sur l'appareil",
                            "Nettoyage du texte"
                        ]
                    )
                } else if isGenerating {
                    GenerationOverlay(
                        title: "Création des flashcards",
                        steps: [
                            readingStepTitle,
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
        .interactiveDismissDisabled(isGenerating || isReading)
    }

    private var readingStepTitle: String {
        switch kind {
        case .photo: "Lecture des photos"
        case .text: "Lecture de vos notes"
        case .pdf, .docx: "Lecture du document"
        }
    }

    // MARK: - Sections

    private var intro: some View {
        Text(introCopy)
            .font(MicaboFont.body)
            .foregroundStyle(MicaboColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var introCopy: String {
        switch kind {
        case .pdf:
            "Le texte est lu sur l'appareil. Un PDF scanné passe par l'OCR d'Apple, sans frais. L'analyse des schémas est facultative."
        case .photo:
            "Scannez plusieurs pages ou choisissez des photos. Le texte est lu ici, hors ligne."
        case .docx:
            "Micabo extrait le texte du document Word sur l'appareil, sans l'envoyer nulle part."
        case .text:
            "Collez vos notes, même brutes. Micabo en fait des flashcards."
        }
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
    private var fileInput: some View {
        if let imported {
            importedCard(imported) {
                showFileImporter = true
            }
        } else {
            dropZone(
                icon: kind == .docx ? "doc.richtext" : "arrow.up.doc",
                tint: kind.swatchTint,
                background: kind.swatchBackground,
                title: kind == .docx ? "Choisir un document Word" : "Choisir un PDF",
                subtitle: kind == .docx ? "Fichier .docx uniquement" : "Jusqu'à quelques centaines de pages"
            ) {
                showFileImporter = true
            }
        }
    }

    @ViewBuilder
    private var photoInput: some View {
        if let imported {
            importedCard(imported) {
                imported = nil
                photoItems = []
            }
        } else {
            VStack(spacing: MicaboSpacing.sm) {
                if VNDocumentCameraViewController.isSupported {
                    dropZone(
                        icon: "camera.viewfinder",
                        tint: kind.swatchTint,
                        background: kind.swatchBackground,
                        title: "Scanner des pages",
                        subtitle: "Jusqu'à \(OnDeviceOCR.pageLimit) pages, à la suite"
                    ) {
                        showScanner = true
                    }

                    Button {
                        photoItems = []
                        showPhotoPicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 15, weight: .medium))
                            Text("Choisir des photos")
                                .font(MicaboFont.cardTitle)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MicaboSecondaryButtonStyle())
                } else {
                    dropZone(
                        icon: "photo.on.rectangle.angled",
                        tint: kind.swatchTint,
                        background: kind.swatchBackground,
                        title: "Choisir des photos",
                        subtitle: "Plusieurs pages, dans l'ordre du cours"
                    ) {
                        photoItems = []
                        showPhotoPicker = true
                    }
                }
            }
        }
    }

    private func importedCard(_ document: ImportedDocument, replace: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            HStack(spacing: MicaboSpacing.sm) {
                coverPreview(document)

                VStack(alignment: .leading, spacing: 3) {
                    Text(document.fileName)
                        .font(MicaboFont.cardTitle)
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(2)
                    Text("\(document.pageCount) page\(document.pageCount > 1 ? "s" : ""), \(document.text.count) caractères lus")
                        .font(MicaboFont.micro)
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                Spacer(minLength: 0)

                Button("Changer", action: replace)
                    .buttonStyle(MicaboQuietButtonStyle())
            }

            if let note = document.extractionNote {
                Text(note)
                    .font(MicaboFont.caption)
                    .foregroundStyle(document.hasUsableText ? MicaboColor.inkTertiary : MicaboColor.caution)
            }
        }
        .micaboCard(padding: MicaboSpacing.sm + 2, radius: MicaboRadius.lg, elevated: false)
    }

    private func dropZone(
        icon: String,
        tint: Color,
        background: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: MicaboSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(background, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
                Text(title)
                    .font(MicaboFont.cardTitle)
                    .foregroundStyle(MicaboColor.ink)
                Text(subtitle)
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

    @ViewBuilder
    private func coverPreview(_ document: ImportedDocument) -> some View {
        if let data = document.coverImage, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
        } else {
            Image(systemName: kind.systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .frame(width: 44, height: 56)
                .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
        }
    }

    private var visionToggle: some View {
        Toggle(isOn: $analyzeVisuals) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Analyser les schémas et images")
                    .font(MicaboFont.body)
                    .foregroundStyle(MicaboColor.ink)
                Text("Option payante : jusqu'à 6 pages partent au modèle de vision. Le texte, lui, a déjà été lu ici.")
                    .font(MicaboFont.micro)
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
        }
        .tint(MicaboColor.accent)
        .padding(.horizontal, MicaboSpacing.xxs)
    }

    private var aiNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock")
                .font(.system(size: 10, weight: .semibold))
            Text("Le texte est extrait sur l'appareil. Seule la rédaction des cartes passe par vos Edge Functions (\(AppConfig.aiModel)).")
                .font(MicaboFont.micro)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(MicaboColor.inkTertiary)
        .padding(.top, MicaboSpacing.xxs)
    }

    // MARK: - Fichiers et photos

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
            return
        }

        Task { await ingestFile(url) }
    }

    @MainActor
    private func ingestFile(_ url: URL) async {
        isReading = true
        defer { isReading = false }

        do {
            let parsed: ImportedDocument
            switch kind {
            case .pdf:
                parsed = try await PDFImportService.extractWithOCR(from: url)
            case .docx:
                parsed = try DocxImportService.extract(from: url)
            case .text, .photo:
                return
            }
            applyImported(parsed)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            offlineFallbackAvailable = false
        }
    }

    @MainActor
    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        isReading = true
        defer { isReading = false }

        var images: [UIImage] = []
        for item in items.prefix(OnDeviceOCR.pageLimit) {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }

        guard !images.isEmpty else {
            errorMessage = PhotoImportError.unreadable.localizedDescription
            return
        }
        await ingestPhotos(images)
    }

    @MainActor
    private func ingestPhotos(_ images: [UIImage]) async {
        isReading = true
        defer { isReading = false }

        do {
            let parsed = try await PhotoImportService.importImages(images)
            applyImported(parsed)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            offlineFallbackAvailable = false
        }
    }

    @MainActor
    private func applyImported(_ document: ImportedDocument) {
        imported = document
        if title.isEmpty { title = document.fileName }
        // Vision seulement si le texte est trop mince : sinon on économise l'appel.
        analyzeVisuals = !document.hasUsableText
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
        let source: CourseSource

        switch kind {
        case .text:
            rawText = pastedText
            images = []
            fileName = nil
            cover = nil
            source = .text
        case .pdf, .photo, .docx:
            guard let imported else { return }
            rawText = imported.text
            images = analyzeVisuals ? imported.pageImages : []
            fileName = imported.fileName
            cover = imported.coverImage
            source = imported.source
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
                source: source,
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

private extension UTType {
    static var docx: UTType {
        UTType(filenameExtension: "docx")
            ?? UTType(importedAs: "org.openxmlformats.wordprocessingml.document")
            ?? .data
    }
}
