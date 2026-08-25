import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

/// Écran d'import : texte, PDF, photos/scan, vidéo YouTube ou Word, puis écriture de la
/// fiche.
///
/// L'import s'arrête à la **fiche**. Il ne génère plus de cartes au passage, et c'est un
/// choix de parcours : un étudiant qui dépose un chapitre veut d'abord le lire, et
/// personne n'a envie de régler des formats de questions avant d'avoir vu ce que Micabo a
/// compris de son document. Les cartes se demandent depuis le cours, une fois la fiche
/// sous les yeux.
///
/// Les cinq sources convergent vers un `ImportedDocument` avant que quoi que ce soit soit
/// analysé. Une vidéo n'a donc pas de branche à elle dans la génération : une fois ses
/// sous-titres transcrits, c'est un document dont le texte a été obtenu autrement.
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
    /// Longueur de la fiche à écrire. Le choix se garde d'un import à l'autre, et se
    /// retrouve dans les réglages : c'est le même réglage, réglé là où il sert.
    @AppStorage(SheetPreferences.lengthKey) private var sheetLength = SheetLength.default
    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var showScanner = false
    @State private var photoItems: [PhotosPickerItem] = []

    // Vidéo YouTube. Le lien, son aperçu, puis sa transcription : les trois sont gardés le
    // temps de l'écran, de sorte qu'un réseau coupé au milieu ne fasse pas tout reprendre.
    @State private var youtubeLink = ""
    @State private var youtubeVideo: YouTubeVideo?
    @State private var isCheckingLink = false

    @State private var isReading = false
    @State private var isGenerating = false
    /// Échec raconté à l'utilisateur, avec ce qu'il peut faire.
    @State private var failure: ImportFailure?
    /// Cours déjà importé qui ressemble à celui-ci : on demande avant de doubler.
    @State private var duplicate: Course?
    @State private var ignoresDuplicate = false

    private let youtube = YouTubeImportService()

    private var canGenerate: Bool {
        switch kind {
        case .text:
            pastedText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 40
        case .youtube:
            // La transcription n'est pas encore là : ce qui autorise à continuer, c'est un
            // aperçu que rien ne bloque.
            imported != nil || youtubeIsReady
        case .pdf, .photo, .docx:
            imported != nil
        }
    }

    /// Un aperçu obtenu, et rien qui empêche de lire la vidéo.
    private var youtubeIsReady: Bool {
        guard let youtubeVideo else { return false }
        return youtubeVideo.blockingReason == nil
    }

    /// Une transcription n'a pas de pages : l'analyse des schémas ne veut rien dire ici.
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
                        case .youtube: youtubeInput
                        }

                        lengthSection

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
                        Task { await start(offline: false) }
                    } label: {
                        HStack(spacing: MicaboSpacing.xs) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                            Text(MicaboCopy.sheetButton)
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
                    GenerationOverlay(title: readingOverlayTitle, steps: readingOverlaySteps)
                } else if isGenerating {
                    GenerationOverlay(
                        title: "Écriture de la fiche",
                        steps: SheetGenerationSteps.all(reading: readingStepTitle)
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
                    Task { await start(offline: false) }
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
                Task { await start(offline: true) }
            }
        case .enableVision:
            Button("Analyser les schémas") {
                failure = nil
                analyzeVisuals = true
                Task { await start(offline: false) }
            }
        case .retry:
            // Reprise, pas reprise à zéro : ce qui a déjà été obtenu est gardé, donc une
            // transcription réussie ne repart pas sur le réseau parce que l'analyse a lâché.
            Button("Réessayer") {
                failure = nil
                Task { await start(offline: false) }
            }
        }
    }

    private var readingStepTitle: String {
        switch kind {
        case .photo: "Lecture des photos"
        case .text: "Lecture de tes notes"
        case .youtube: "Lecture des sous-titres"
        case .pdf, .docx: "Lecture du document"
        }
    }

    private var readingOverlayTitle: String {
        kind == .youtube ? "Lecture de la vidéo" : "Lecture des pages"
    }

    private var readingOverlaySteps: [String] {
        kind == .youtube
            ? ["Choix de la piste de sous-titres", "Téléchargement de la transcription", "Nettoyage du texte"]
            : ["Préparation des images", "OCR sur l'appareil", "Nettoyage du texte"]
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
            "Le texte est lu sur l'appareil. Un PDF scanné passe par l'OCR d'Apple, sans frais. Micabo en écrit ensuite la fiche."
        case .photo:
            "Scanne plusieurs pages ou choisis des photos. Le texte est lu ici, hors ligne, puis mis en fiche."
        case .youtube:
            "Micabo lit les sous-titres de la vidéo, jamais son audio. Une vidéo qui n'en a pas ne peut donc pas être fichée."
        case .docx:
            "Micabo extrait le texte du document Word sur l'appareil, puis en écrit la fiche."
        case .text:
            "Colle tes notes, même brutes. Micabo en fait une fiche qui se relit."
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

    @ViewBuilder
    private var youtubeInput: some View {
        if let document = imported {
            // La transcription est déjà là : c'est un document comme un autre, et on
            // l'affiche comme tel.
            importedCard(document) { resetYouTube() }
        } else {
            YouTubeImportSection(
                link: $youtubeLink,
                video: youtubeVideo,
                isChecking: isCheckingLink,
                onCheck: { Task { await checkLink() } },
                onReset: resetYouTube
            )
            .onChange(of: youtubeLink) { _, new in
                // Un lien collé est complet du premier coup : on va chercher l'aperçu sans
                // demander un appui de plus. Un lien tapé à la main ne devient valide qu'à
                // son dernier caractère, donc la règle vaut aussi pour lui.
                guard youtubeVideo == nil, !isCheckingLink, YouTubeLink.isValid(new) else { return }
                Task { await checkLink() }
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

    /// Combien de fiche on veut. Le réglage est ici, juste avant le bouton qui l'utilise,
    /// parce que la réponse dépend du document qu'on vient de déposer : un chapitre entier
    /// et deux pages de notes ne demandent pas la même fiche.
    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Longueur de la fiche")

            // En flux et non en rangée : les trois libellés ne tiennent pas sur une ligne
            // d'iPhone compact, et une pastille tronquée ne dit plus ce qu'elle choisit.
            MicaboFlowLayout(spacing: MicaboSpacing.xs, lineSpacing: MicaboSpacing.xs) {
                ForEach(SheetLength.allCases) { value in
                    MicaboSelectChip(title: value.title, isSelected: value == sheetLength) {
                        Haptics.selection()
                        withAnimation(.easeOut(duration: 0.2)) { sheetLength = value }
                    }
                }
            }

            MicaboSectionFootnote(text: "\(sheetLength.detail) \(sheetLength.readingHint) de lecture.")
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

    /// Ce qui part de l'appareil, dit franchement. La vidéo est la seule source dont le
    /// texte n'est pas extrait ici : ses sous-titres sont récupérés par l'Edge Function, et
    /// l'écrire autrement serait mentir sur la seule promesse que l'app tient partout
    /// ailleurs.
    private var aiNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock")
                .font(.system(size: 10, weight: .semibold))
            Text(privacyCopy)
                .font(MicaboFont.micro)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(MicaboColor.inkTertiary)
        .padding(.top, MicaboSpacing.xxs)
    }

    private var privacyCopy: String {
        kind == .youtube
            ? "Le lien et les sous-titres passent par tes Edge Functions, qui écrivent ensuite la fiche (\(AppConfig.aiModel))."
            : "Le texte est extrait sur l'appareil. Seule la rédaction de la fiche passe par tes Edge Functions (\(AppConfig.aiModel))."
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
            case .text, .photo, .youtube:
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
        // Vision seulement si le texte est trop mince, et jamais sur une transcription qui
        // n'a pas de pages : sinon on dépense un appel pour rien.
        analyzeVisuals = showsVisionToggle && !document.hasUsableText
    }

    // MARK: - Vidéo YouTube

    /// L'aperçu de la vidéo. Aucune transcription n'est téléchargée à ce stade, et aucune
    /// génération n'est lancée : c'est ce qui permet de refuser une vidéo de trois heures
    /// sans avoir rien dépensé.
    @MainActor
    private func checkLink() async {
        let link = youtubeLink.trimmingCharacters(in: .whitespacesAndNewlines)

        guard YouTubeLink.isValid(link) else {
            youtubeVideo = nil
            failure = youtubeFailure(YouTubeImportError.invalidLink)
            return
        }

        guard !isCheckingLink else { return }
        isCheckingLink = true
        defer { isCheckingLink = false }

        do {
            let video = try await youtube.preview(link: link)
            youtubeVideo = video
            if title.isEmpty { title = video.title }
        } catch {
            youtubeVideo = nil
            failure = youtubeFailure(error)
        }
    }

    /// Un refus de l'import vidéo, avec son titre et sa sortie. Le message vient de
    /// `YouTubeImportError` et n'est pas retouché : ce sont les phrases que l'utilisateur
    /// doit lire, au mot près.
    private func youtubeFailure(_ error: Error) -> ImportFailure {
        guard let youtubeError = error as? YouTubeImportError else {
            return ImportFailure(
                title: "Lecture impossible",
                message: describe(error),
                recovery: isRecoverable(error) ? .retry : .none
            )
        }
        return ImportFailure(
            title: youtubeError.failureTitle,
            message: youtubeError.errorDescription ?? "",
            recovery: youtubeError.allowsRetry ? .retry : .none
        )
    }

    private func resetYouTube() {
        // Le titre proposé venait de la vidéo : garder celui de la précédente serait pire
        // que de le vider. Un titre saisi à la main, lui, reste.
        if let previous = youtubeVideo?.title, title == previous {
            title = ""
        }
        imported = nil
        youtubeVideo = nil
        youtubeLink = ""
    }

    /// Télécharge la transcription et en fait un document d'import.
    ///
    /// Rend `false` quand ça a échoué, pour que l'appelant n'enchaîne pas sur l'analyse. Le
    /// document obtenu reste en mémoire : si l'analyse échoue ensuite, « Réessayer » repart
    /// d'ici, pas du lien.
    @MainActor
    private func loadTranscript() async -> Bool {
        guard let video = youtubeVideo else { return false }

        // Le garde qui compte : une vidéo hors limite, ou sans sous-titres, ne déclenche
        // aucun appel, ni de transcription ni de génération.
        if let reason = video.blockingReason {
            failure = youtubeFailure(reason)
            return false
        }

        isReading = true
        defer { isReading = false }

        do {
            let transcript = try await youtube.transcript(link: youtubeLink)
            let cover = await youtube.cover(for: video)
            applyImported(
                YouTubeImportService.document(video: video, transcript: transcript, cover: cover)
            )
            return true
        } catch {
            failure = youtubeFailure(error)
            return false
        }
    }

    // MARK: - Génération

    /// Le bouton du bas, et toutes les reprises.
    ///
    /// La vidéo est la seule source dont le texte s'obtient en ligne, donc la seule qui a
    /// une étape avant l'analyse. Elle est ici et pas dans `generate` pour que la reprise
    /// soit franche : ce qui a déjà été obtenu n'est pas redemandé, et rien n'est écrit en
    /// base avant que l'analyse ait réussi.
    @MainActor
    private func start(offline: Bool) async {
        guard !isGenerating, !isReading else { return }

        if kind == .youtube, imported == nil {
            guard await loadTranscript() else { return }
        }
        await generate(offline: offline)
    }

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
        case .pdf, .photo, .docx, .youtube:
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
            sourceName: fileName,
            studyLevel: OnboardingPreferences.studyLevel,
            country: OnboardingPreferences.schoolingCountry,
            sheetLength: sheetLength,
            // La matière n'est pas encore connue : c'est le modèle qui la trouve, et la
            // fonction la devine sur le texte pour choisir ses consignes de rédaction.
            sourceKind: source
        )

        // Étape 1 : la fiche. Si elle échoue, rien n'a été créé.
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

        // Étape 2 : le cours est enregistré avec sa fiche. L'import s'arrête là : les
        // cartes se demandent depuis le cours, la fiche sous les yeux.
        do {
            let course = try CourseRepository.save(
                generated,
                source: source,
                rawText: rawText,
                fileName: fileName,
                coverImageData: cover,
                in: modelContext
            )
            onCreated(course)
        } catch {
            failure = ImportFailure(
                title: "Enregistrement impossible",
                message: "\(describe(error)) Réessaie dans un instant.",
                recovery: .none
            )
        }
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
        /// Construire la fiche à partir du texte brut, sans IA.
        case buildOffline
        /// Relancer en envoyant les pages au modèle de vision.
        case enableVision
        /// Reprendre là où ça s'est arrêté : le réseau a lâché, rien n'est perdu.
        case retry
    }

    let id = UUID()
    var title: String
    var message: String
    var recovery: Recovery
}

/// Contrôle du texte extrait avant d'appeler quoi que ce soit.
///
/// C'est le cas de la photo de cahier manuscrit : l'OCR rend trois mots, et sans ce garde
/// l'utilisateur attendait une analyse pour récolter une fiche vide.
enum ImportReadiness {
    /// En dessous, il n'y a pas de quoi écrire une fiche.
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
                message: "\(read) Colle au moins un paragraphe : c'est le minimum pour en tirer une fiche.",
                recovery: .none
            )
        case .youtube:
            // Le serveur refuse déjà une transcription trop courte, avec son propre seuil.
            // Ce garde n'est là que si elle passe quand même : la phrase reste la même,
            // écrite en un seul endroit.
            return ImportFailure(
                title: YouTubeImportError.transcriptTooShort.failureTitle,
                message: YouTubeImportError.transcriptTooShort.errorDescription ?? "",
                recovery: .none
            )
        }
    }
}

private extension UTType {
    static var docx: UTType {
        UTType(filenameExtension: "docx")
            ?? UTType(importedAs: "org.openxmlformats.wordprocessingml.document")
    }
}
