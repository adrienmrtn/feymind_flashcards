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
///
/// `ImportKind.cards` n'ouvre pas cet écran (`CreateDeckView` s'en charge), mais le type
/// le porte encore : chaque `switch kind` doit donc le connaître, sinon le compilateur
/// refuse le fichier entier et invente une cascade de « cannot find in scope ».
struct ImportView: View {
    let kind: ImportKind
    var onCreated: (Course) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var title = ""
    @State private var pastedText = ""
    @State private var imported: ImportedDocument?
    /// L'analyse des schémas n'est plus une case à cocher d'avance : elle ne s'allume que
    /// depuis l'échec qui la réclame, quand un document scanné n'a rendu aucun texte
    /// exploitable. Cocher une option payante avant de savoir si elle sert est une décision
    /// qu'on ne peut pas prendre, et l'écran la posait en premier.
    @State private var analyzeVisuals = false
    /// Longueur de la fiche à écrire. Le choix se garde d'un import à l'autre, et se
    /// retrouve dans les réglages : c'est le même réglage, réglé là où il sert.
    /// Le volume de fiche demandé, en blocs. Écrit dans les réglages à chaque cran, pour
    /// que le prochain import reparte de là où on avait laissé le curseur.
    @State private var sheetBlocks = SheetPreferences.blocks
    /// Qui pourra retrouver le cours. Gardé d'un import à l'autre pour la même raison.
    @AppStorage(CourseVisibility.importKey) private var visibility = CourseVisibility.standard
    /// `nil` = langue du document. Une valeur force la fiche dans cette langue.
    @State private var generationLanguage: ContentLanguage?
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

    /// Vrai quand le document a des pages à envoyer au modèle de vision. Une transcription
    /// n'en a pas, et l'analyse des schémas n'y voudrait rien dire.
    private var supportsVisionAnalysis: Bool {
        kind == .pdf || kind == .photo
    }

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
        case .cards:
            // Un paquet n'emprunte pas cet écran : `CreateDeckView` le crée.
            false
        }
    }

    /// Un aperçu obtenu, et rien qui empêche de lire la vidéo. Un cours trop
    /// long n'empêche plus : on lira le début.
    private var youtubeIsReady: Bool {
        guard let youtubeVideo else { return false }
        return youtubeVideo.blockingReason == nil
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                        header
                        titleField

                        switch kind {
                        case .text: textInput
                        case .pdf, .docx: fileInput
                        case .photo: photoInput
                        case .youtube: youtubeInput
                        case .cards: EmptyView()
                        }

                        lengthSection
                        languageSection
                        visibilitySection
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
                            Text(MicaboCopy.sheetButton())
                        }
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle(tint: canGenerate ? MicaboColor.accent : MicaboColor.strokeStrong))
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
                        title: L10n.t("ios.writingSheet", locale: .resolved()),
                        steps: SheetGenerationSteps.all(reading: readingStepTitle)
                    )
                }
            }
            .alert(failure?.title ?? "", isPresented: .constant(failure != nil), presenting: failure) { failure in
                recoveryButton(for: failure.recovery)
                Button(L10n.t("app.a11y.close", locale: .resolved()), role: .cancel) { self.failure = nil }
            } message: { failure in
                Text(failure.message)
            }
            .confirmationDialog(
                L10n.t("ios.alreadyImported", locale: .resolved()),
                isPresented: .constant(duplicate != nil),
                titleVisibility: .visible,
                presenting: duplicate
            ) { existing in
                Button(L10n.t("ios.openQuoted", locale: .resolved(), vars: ["title": existing.title])) {
                    duplicate = nil
                    onCreated(existing)
                }
                Button(L10n.t("ios.importAnyway", locale: .resolved())) {
                    duplicate = nil
                    ignoresDuplicate = true
                    Task { await start(offline: false) }
                }
                Button(L10n.t("app.common.cancel", locale: .resolved()), role: .cancel) { duplicate = nil }
            } message: { existing in
                Text(L10n.t("ios.duplicateHelp", locale: .resolved(), vars: ["title": existing.title]))
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
            Button(L10n.t("ios.createWithoutAI", locale: .resolved())) {
                failure = nil
                Task { await start(offline: true) }
            }
        case .enableVision:
            Button(L10n.t("ios.analyzeFigures", locale: .resolved())) {
                failure = nil
                analyzeVisuals = true
                Task { await start(offline: false) }
            }
        case .retry:
            // Reprise, pas reprise à zéro : ce qui a déjà été obtenu est gardé, donc une
            // transcription réussie ne repart pas sur le réseau parce que l'analyse a lâché.
            Button(L10n.t("ios.retry", locale: .resolved())) {
                failure = nil
                Task { await start(offline: false) }
            }
        }
    }

    private var readingStepTitle: String {
        switch kind {
        case .photo: L10n.t("ios.readPhotos", locale: .resolved())
        case .text: L10n.t("ios.readNotes", locale: .resolved())
        case .youtube: L10n.t("ios.readSubtitles", locale: .resolved())
        case .pdf, .docx: L10n.t("ios.genStepDoc", locale: .resolved())
        case .cards: L10n.t("ios.prepDeck", locale: .resolved())
        }
    }

    private var readingOverlayTitle: String {
        kind == .youtube
            ? L10n.t("ios.readVideo", locale: .resolved())
            : L10n.t("ios.readPages", locale: .resolved())
    }

    private var readingOverlaySteps: [String] {
        kind == .youtube
            ? [
                L10n.t("ios.pickSubtitleTrack", locale: .resolved()),
                L10n.t("ios.downloadTranscript", locale: .resolved()),
                L10n.t("ios.cleanText", locale: .resolved()),
            ]
            : [
                L10n.t("ios.prepImages", locale: .resolved()),
                L10n.t("ios.ocrOnDevice", locale: .resolved()),
                L10n.t("ios.cleanText", locale: .resolved()),
            ]
    }

    // MARK: - Sections

    private var header: some View {
        MicaboScreenHeader(
            title: kind.title(locale: i18n?.locale ?? .resolved()),
            eyebrow: i18n?.t("ios.newCourse") ?? "Nouveau cours",
            back: MicaboHeaderBack.close { dismiss() }
        )
        .padding(.top, MicaboSpacing.xs)
        .padding(.bottom, MicaboSpacing.xxs)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L10n.t("ios.fieldTitle", locale: .resolved()))
                .font(MicaboFont.captionEmphasis)
                .foregroundStyle(MicaboColor.ink)

            TextField(L10n.t("ios.titleOptionalAI", locale: .resolved()), text: $title)
                .font(MicaboFont.body)
                .padding(MicaboSpacing.sm)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        }
    }

    private var textInput: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(L10n.t("ios.fieldContent", locale: .resolved()))
                    .font(MicaboFont.captionEmphasis)
                    .foregroundStyle(MicaboColor.ink)
                Spacer()
                Text(L10n.t("ios.charCount", locale: .resolved(), vars: ["count": "\(pastedText.count)"]))
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
                    Text(L10n.t("ios.pasteChapter", locale: .resolved()))
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
                title: kind == .docx
                    ? L10n.t("ios.chooseWord", locale: .resolved())
                    : L10n.t("ios.choosePDF", locale: .resolved()),
                subtitle: kind == .docx
                    ? L10n.t("ios.wordOnly", locale: .resolved())
                    : L10n.t("ios.pdfPagesHelp", locale: .resolved())
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
                        title: L10n.t("ios.scanPages", locale: .resolved()),
                        subtitle: L10n.t("ios.scanHelp", locale: .resolved(), vars: ["n": "\(OnDeviceOCR.pageLimit)"])
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
                            Text(L10n.t("ios.pickPhotos", locale: .resolved()))
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
                        title: L10n.t("ios.pickPhotos", locale: .resolved()),
                        subtitle: L10n.t("ios.pickPhotosOrder", locale: .resolved())
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
                    Text(L10n.t("ios.pagesRead", locale: .resolved(), vars: [
                        "pages": "\(document.pageCount)",
                        "chars": "\(document.text.count)",
                    ]))
                        .font(MicaboFont.micro)
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                Spacer(minLength: 0)

                Button(L10n.t("app.common.change", locale: .resolved()), action: replace)
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
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .soft))
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

    /// **Combien de fiche on veut, au curseur.**
    ///
    /// Le curseur n'avait que **trois positions**, ce qui n'est pas un curseur : trois crans
    /// se comptent, se visent, et ne se distinguent en rien de trois boutons — sauf qu'ils
    /// sont plus durs à atteindre. Il court maintenant sur le volume réel de la fiche, de
    /// huit à trente-quatre blocs, et le doigt le suit sans à-coups.
    ///
    /// Le nom du format reste affiché, mais il devient une **conséquence** : il dit dans
    /// quelle famille on vient de tomber, et la durée de lecture à côté bouge d'un cran à
    /// l'autre, y compris à l'intérieur d'une famille. C'est ce qui fait qu'on sent le
    /// curseur travailler au lieu de le voir sauter.
    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                MicaboSectionCaption(text: L10n.t("ios.sheetLengthCaption", locale: .resolved()))

                Spacer(minLength: MicaboSpacing.xs)

                Text("\(sheetFormat.title) · \(SheetPreferences.readingHint(forBlocks: sheetBlocks))")
                    .font(MicaboFont.captionEmphasis)
                    .foregroundStyle(MicaboColor.ink)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.2), value: sheetBlocks)
            }

            // Pas de `step:` : un pas déclaré fait crocheter le curseur d'une valeur à
            // l'autre, et sur vingt-sept crans le geste se met à vibrer. Le doigt glisse en
            // continu, et c'est l'arrondi de la liaison qui décide du nombre de blocs.
            Slider(
                value: blocksSlider,
                in: Double(SheetLength.blockBounds.lowerBound)...Double(SheetLength.blockBounds.upperBound)
            )
            .tint(MicaboColor.progress)
        }
        .onChange(of: sheetBlocks) { _, newValue in
            SheetPreferences.blocks = newValue
        }
    }

    private var sheetFormat: SheetLength {
        SheetLength.containing(blocks: sheetBlocks)
    }

    /// Le pont entre le geste, qui est continu, et le réglage, qui est un entier.
    ///
    /// La vibration ne part qu'au **changement de blocs**, jamais à chaque image : un
    /// curseur qui vibre soixante fois par seconde ne donne pas une sensation de précision,
    /// il donne l'impression que le téléphone bourdonne.
    private var blocksSlider: Binding<Double> {
        Binding(
            get: { Double(sheetBlocks) },
            set: { newValue in
                let rounded = Int(newValue.rounded())
                guard rounded != sheetBlocks else { return }
                Haptics.selection()
                sheetBlocks = rounded
            }
        )
    }

    /// **Dans quelle langue écrire la fiche.**
    ///
    /// Par défaut on reste dans celle du document. Forcer l'anglais sur un
    /// polycopié français est un choix, pas un défaut caché derrière le pays.
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            MicaboSectionCaption(text: L10n.t("ios.sheetLanguageCaption", locale: .resolved()))

            Menu {
                Button(L10n.t("ios.docLanguage", locale: .resolved())) { generationLanguage = nil }
                Divider()
                ForEach(ContentLanguage.allCases) { value in
                    Button(value.label) { generationLanguage = value }
                }
            } label: {
                HStack {
                    Text(generationLanguage?.label ?? L10n.t("ios.docLanguage", locale: .resolved()))
                        .font(MicaboFont.body)
                        .foregroundStyle(MicaboColor.ink)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
                .padding(MicaboSpacing.sm)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))

            Text(generationLanguage == nil
                 ? L10n.t("ios.writesInCourseLang", locale: .resolved())
                 : L10n.t("ios.sheetTranslated", locale: .resolved()))
                .font(MicaboFont.caption)
                .foregroundStyle(MicaboColor.inkTertiary)
        }
    }

    /// **Qui pourra la retrouver, décidé à l'import.**
    ///
    /// Plus de dépôt public : uniquement les amis, ou soi seul. Le choix se garde d'un
    /// import à l'autre, comme la longueur : quelqu'un qui travaille en privé n'a pas à le
    /// redire à chaque document.
    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MicaboSectionCaption(text: L10n.t("app.course.visibility.label", locale: .resolved()))

            HStack(spacing: MicaboSpacing.xs) {
                ForEach(CourseVisibility.choosable) { value in
                    MicaboSelectChip(title: value.title, isSelected: value == visibility.asChoice) {
                        withAnimation(.easeOut(duration: 0.2)) { visibility = value }
                    }
                }
            }
        }
    }

    // MARK: - Fichiers et photos

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result {
                report(error, title: L10n.t("ios.err.unreadableFile", locale: .resolved()))
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
            case .text, .photo, .youtube, .cards:
                return
            }
            applyImported(parsed)
        } catch {
            report(error, title: L10n.t("ios.err.readFailed", locale: .resolved()))
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
            report(PhotoImportError.unreadable, title: L10n.t("ios.err.unreadablePhotos", locale: .resolved()))
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
            report(error, title: L10n.t("ios.err.readFailed", locale: .resolved()))
        }
    }

    @MainActor
    private func applyImported(_ document: ImportedDocument) {
        imported = document
        if title.isEmpty { title = document.fileName }
        // Une fiche extraite d'un PDF ou d'une photo sans les pages ne peut pas recadrer
        // les schémas. La passe visuelle coûte un appel, et c'est le prix d'une figure
        // réelle plutôt que d'un dessin inventé.
        analyzeVisuals = document.source == .pdf || document.source == .photo
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
                title: L10n.t("ios.err.readFailed", locale: .resolved()),
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

        // Le garde qui compte : une vidéo sans sous-titres ne déclenche
        // aucun appel. Un cours trop long, lui, se lit par le début.
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
        guard !isGenerating, !isReading, kind.producesSheet else { return }

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
        case .cards:
            return
        }

        // Un texte illisible ne donnera rien de bon : on le dit avant de dépenser un appel.
        if let unreadable = ImportReadiness.failure(
            text: rawText,
            hasImages: !images.isEmpty,
            canEnableVision: supportsVisionAnalysis && !analyzeVisuals,
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
            language: generationLanguage,
            sheetLength: sheetFormat,
            sheetBlocks: sheetBlocks,
            // La matière n'est pas encore connue : c'est le modèle qui la trouve, et la
            // fonction la devine sur le texte pour choisir ses consignes de rédaction.
            sourceKind: source
        )

        // Étape 1 : la fiche. Si elle échoue, rien n'a été créé.
        var generated: GeneratedCourse
        if offline {
            generated = OfflineCourseBuilder.build(
                from: rawText,
                hintTitle: title.nilIfBlank,
                sourceName: fileName
            )
        } else {
            do {
                generated = try await aiService.generateCourse(request)
                if let sheet = generated.sheet {
                    generated.sheet = sheet.attachingFigureImages(from: images)
                }
            } catch {
                failure = ImportFailure(
                    title: L10n.t("ios.err.analysisFailed", locale: .resolved()),
                    message: "\(describe(error)) \(L10n.t("ios.err.notImported", locale: .resolved()))",
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
                visibility: visibility.asChoice,
                in: modelContext
            )
            onCreated(course)
        } catch {
            failure = ImportFailure(
                title: L10n.t("ios.err.saveFailed", locale: .resolved()),
                message: "\(describe(error)) \(L10n.t("ios.err.retrySoon", locale: .resolved()))",
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
            ? L10n.t("ios.noTextRead", locale: .resolved())
            : L10n.t("ios.err.onlyCharsRead", locale: .resolved(), vars: ["count": "\(usable.count)"])

        switch kind {
        case .photo:
            return ImportFailure(
                title: L10n.t("ios.err.pagesUnreadable", locale: .resolved()),
                message: "\(read) \(L10n.t(canEnableVision ? "ios.err.photoBlurHelpVision" : "ios.err.photoBlurHelp", locale: .resolved()))",
                recovery: canEnableVision ? .enableVision : .none
            )
        case .pdf:
            return ImportFailure(
                title: L10n.t("ios.err.pdfAlmostEmpty", locale: .resolved()),
                message: "\(read) \(L10n.t(canEnableVision ? "ios.err.pdfScanHelpVision" : "ios.err.pdfScanHelp", locale: .resolved()))",
                recovery: canEnableVision ? .enableVision : .none
            )
        case .docx:
            return ImportFailure(
                title: L10n.t("ios.err.docAlmostEmpty", locale: .resolved()),
                message: "\(read) \(L10n.t("ios.err.docxEmptyHelp", locale: .resolved()))",
                recovery: .none
            )
        case .text:
            return ImportFailure(
                title: L10n.t("ios.err.missingText", locale: .resolved()),
                message: "\(read) \(L10n.t("ios.err.pasteParagraph", locale: .resolved()))",
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
        case .cards:
            return nil
        }
    }
}

private extension UTType {
    static var docx: UTType {
        UTType(filenameExtension: "docx")
            ?? UTType(importedAs: "org.openxmlformats.wordprocessingml.document")
    }
}
