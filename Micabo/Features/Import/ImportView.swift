import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

/// Écran d'import : texte, PDF, photos/scan ou Word, puis génération des cartes.
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
    /// Échec raconté à l'utilisateur, avec ce qu'il peut faire.
    @State private var failure: ImportFailure?
    /// Cours déjà importé qui ressemble à celui-ci : on demande avant de doubler.
    @State private var duplicate: Course?
    @State private var ignoresDuplicate = false

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
                        header
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
                            Text("Générer les cartes")
                        }
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle(tint: canGenerate ? MicaboColor.ink : MicaboColor.strokeStrong))
                    .disabled(!canGenerate || isGenerating || isReading)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
                        title: "Création des cartes",
                        steps: [
                            readingStepTitle,
                            "Repérage des notions clés",
                            "Rédaction des questions",
                            "Vérification des réponses"
                        ]
                    )
                }
            }
            .alert(failure?.title ?? "", isPresented: .constant(failure != nil), presenting: failure) { failure in
                recoveryButton(for: failure.recovery)
                Button("Fermer", role: .cancel) { self.failure = nil }
            } message: { failure in
                Text(failure.message)
            }
            .confirmationDialog(
                "Ce chapitre semble déjà importé",
                isPresented: .constant(duplicate != nil),
                titleVisibility: .visible,
                presenting: duplicate
            ) { existing in
                Button("Ouvrir « \(existing.title) »") {
                    duplicate = nil
                    onCreated(existing)
                }
                Button("Importer quand même") {
                    duplicate = nil
                    ignoresDuplicate = true
                    Task { await generate(offline: false) }
                }
                Button("Annuler", role: .cancel) { duplicate = nil }
            } message: { existing in
                Text("« \(existing.title) » contient déjà ce contenu. Tu peux l'ouvrir plutôt que d'en créer un doublon.")
            }
        }
        .interactiveDismissDisabled(isGenerating || isReading)
    }

    /// Le bouton d'action de l'alerte : chaque échec propose une sortie utile.
    @ViewBuilder
    private func recoveryButton(for recovery: ImportFailure.Recovery) -> some View {
        switch recovery {
        case .none:
            EmptyView()
        case .buildOffline:
            Button("Créer sans IA") {
                failure = nil
                Task { await generate(offline: true) }
            }
        case .enableVision:
            Button("Analyser les schémas") {
                failure = nil
                analyzeVisuals = true
                Task { await generate(offline: false) }
            }
        case .openCourse(let course):
            Button("Voir le cours") {
                failure = nil
                onCreated(course)
            }
        }
    }

    private var readingStepTitle: String {
        switch kind {
        case .photo: "Lecture des photos"
        case .text: "Lecture de tes notes"
        case .pdf, .docx: "Lecture du document"
        }
    }

    // MARK: - Sections

    private var header: some View {
        MicaboScreenHeader(
            title: kind.title,
            eyebrow: "Nouveau cours",
            back: MicaboHeaderBack.close { dismiss() }
        )
        .padding(.top, MicaboSpacing.xs)
        .padding(.bottom, MicaboSpacing.xxs)
    }

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
            "Scanne plusieurs pages ou choisis des photos. Le texte est lu ici, hors ligne."
        case .docx:
            "Micabo extrait le texte du document Word sur l'appareil, sans l'envoyer nulle part."
        case .text:
            "Colle tes notes, même brutes. Micabo en fait des cartes."
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
                    Text("Colle ici ton chapitre, tes notes de cours ou un article.")
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
        if let document = imported {
            importedCard(document) {
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
        if let document = imported {
            importedCard(document) {
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
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous)
                    .strokeBorder(MicaboColor.strokeStrong, style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
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
            VStack(alignment: .leading, spacing: 3) {
                Text("Analyser les schémas et images")
                    .font(MicaboFont.rowTitle)
                    .foregroundStyle(MicaboColor.ink)
                Text("Option payante : jusqu'à 6 pages partent au modèle de vision. Le texte, lui, a déjà été lu ici.")
                    .font(MicaboFont.hanken(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
        }
        .tint(MicaboColor.accent)
        .padding(16)
        .micaboGroup()
    }

    private var aiNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock")
                .font(.system(size: 10, weight: .semibold))
            Text("Le texte est extrait sur l'appareil. Seule la rédaction des cartes passe par tes Edge Functions (\(AppConfig.aiModel)).")
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
                report(error, title: "Fichier illisible")
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
            report(error, title: "Lecture impossible")
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
            report(PhotoImportError.unreadable, title: "Photos illisibles")
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
            report(error, title: "Lecture impossible")
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

        // Un texte illisible ne donnera rien de bon : on le dit avant de dépenser un appel.
        if let unreadable = ImportReadiness.failure(
            text: rawText,
            hasImages: !images.isEmpty,
            canEnableVision: showsVisionToggle && !analyzeVisuals,
            kind: kind
        ) {
            failure = unreadable
            return
        }

        // Le même chapitre deux fois : on propose d'ouvrir l'existant plutôt que de doubler.
        if !ignoresDuplicate,
           let existing = CourseRepository.duplicate(
               title: title.nilIfBlank ?? fileName ?? "",
               rawText: rawText,
               in: modelContext
           ) {
            duplicate = existing
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        let request = CourseGenerationRequest(
            rawText: rawText,
            pageImages: images,
            hintTitle: title.nilIfBlank,
            sourceName: fileName
        )

        // Étape 1 : la fiche du cours. Si elle échoue, rien n'a été créé.
        let generated: GeneratedCourse
        if offline {
            generated = OfflineCourseBuilder.build(
                from: rawText,
                hintTitle: title.nilIfBlank,
                sourceName: fileName
            )
        } else {
            do {
                generated = try await aiService.generateCourse(request)
            } catch {
                failure = ImportFailure(
                    title: "L'analyse du document a échoué",
                    message: "\(describe(error)) Le document n'a pas été importé.",
                    recovery: isRecoverable(error) ? .buildOffline : .none
                )
                return
            }
        }

        // Étape 2 : le cours est enregistré. À partir d'ici, un échec ne doit plus rien perdre.
        let course: Course
        do {
            course = try CourseRepository.save(
                generated,
                source: source,
                rawText: rawText,
                fileName: fileName,
                coverImageData: cover,
                in: modelContext
            )
        } catch {
            failure = ImportFailure(
                title: "Enregistrement impossible",
                message: "\(describe(error)) Réessaie dans un instant.",
                recovery: .none
            )
            return
        }

        // Étape 3 : les cartes. Le cours existe déjà, donc tout échec est récupérable.
        var cards: [GeneratedFlashcard] = []
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
                    failure = ImportFailure(
                        title: "Le cours est là, les cartes non",
                        message: "\(describe(error)) « \(course.title) » est enregistré : relance la génération depuis le cours quand tu veux.",
                        recovery: .openCourse(course)
                    )
                    return
                }
            }
        }

        let inserted = (try? CourseRepository.addFlashcards(cards, to: course, in: modelContext)) ?? []

        guard !inserted.isEmpty else {
            failure = ImportFailure(
                title: "Aucune carte exploitable",
                message: "Le cours « \(course.title) » est enregistré, mais rien n'a pu être transformé en carte. Ouvre-le pour en écrire une à la main ou relancer la génération.",
                recovery: .openCourse(course)
            )
            return
        }

        // Les langues se révisent dans les deux sens : la carte inverse est créée d'office,
        // avec sa propre planification.
        if SubjectHeuristics.isLanguage(subject: course.subject, title: course.title) {
            try? CourseRepository.addReverseCards(for: course, in: modelContext)
        }

        onCreated(course)
    }

    private func report(_ error: Error, title: String) {
        failure = ImportFailure(title: title, message: describe(error), recovery: .none)
    }

    private func describe(_ error: Error) -> String {
        let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return text.hasSuffix(".") ? text : "\(text)."
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

/// Un échec d'import raconté à l'utilisateur : ce qui a lâché, et par où sortir.
struct ImportFailure: Identifiable {
    enum Recovery {
        case none
        /// Construire les cartes à partir du texte brut, sans IA.
        case buildOffline
        /// Relancer en envoyant les pages au modèle de vision.
        case enableVision
        /// Le cours est enregistré : on l'ouvre au lieu de perdre le travail.
        case openCourse(Course)
    }

    let id = UUID()
    var title: String
    var message: String
    var recovery: Recovery
}

/// Contrôle du texte extrait avant d'appeler quoi que ce soit.
///
/// C'est le cas de la photo de cahier manuscrit : l'OCR rend trois mots, et sans ce garde
/// l'utilisateur attendait une génération pour récolter des cartes vides.
enum ImportReadiness {
    /// En dessous, il n'y a pas de quoi écrire des cartes.
    static let minimumCharacters = 120

    static func failure(
        text: String,
        hasImages: Bool,
        canEnableVision: Bool,
        kind: ImportKind
    ) -> ImportFailure? {
        let usable = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard usable.count < minimumCharacters, !hasImages else { return nil }

        let read = usable.isEmpty
            ? "Aucun texte n'a été lu."
            : "Seuls \(usable.count) caractères ont été lus."

        switch kind {
        case .photo:
            return ImportFailure(
                title: "Ces pages sont illisibles",
                message: "\(read) Une écriture manuscrite serrée ou une photo floue résistent à l'OCR. Reprends la photo bien à plat et en pleine lumière\(canEnableVision ? ", ou laisse le modèle de vision analyser les pages" : "").",
                recovery: canEnableVision ? .enableVision : .none
            )
        case .pdf:
            return ImportFailure(
                title: "Ce PDF ne contient presque pas de texte",
                message: "\(read) Il s'agit sans doute d'un scan d'images\(canEnableVision ? " : active l'analyse des schémas pour l'envoyer au modèle de vision" : "").",
                recovery: canEnableVision ? .enableVision : .none
            )
        case .docx:
            return ImportFailure(
                title: "Ce document est presque vide",
                message: "\(read) Vérifie qu'il ne contient pas seulement des images, puis réessaie.",
                recovery: .none
            )
        case .text:
            return ImportFailure(
                title: "Il manque du texte",
                message: "\(read) Colle au moins un paragraphe : c'est le minimum pour en tirer des cartes.",
                recovery: .none
            )
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
