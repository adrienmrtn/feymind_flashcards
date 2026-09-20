import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// **Les supports du deck, dans des cases vides.**
///
/// L'écran montre quatre emplacements avant qu'il n'y ait quoi que ce soit dedans, et c'est
/// tout le propos : un seul bouton « importer un document » fait croire qu'on n'en importe
/// qu'un. Un deck couvre une matière entière — le cours du prof, les annales, les photos du
/// tableau — et l'écran doit le dire avant d'être rempli, pas après.
///
/// **Chaque case lit son document de son côté.** Un PDF de cent pages passe par l'OCR et
/// prend plusieurs secondes ; pendant ce temps les autres cases restent utilisables, et
/// c'est pour ça que l'état de lecture vit sur la case (`DeckMaterial`) et non sur l'écran.
/// Un écran qui se bloquerait entier pendant la lecture du premier document ferait attendre
/// quatre fois de suite quelqu'un qui en dépose quatre.
struct DeckMaterialsStepView: View {
    @Bindable var setup: DeckSetup
    var onNext: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// La case qu'on est en train de remplir : c'est elle qui recevra le document.
    @State private var target: DeckMaterial?
    @State private var showChoice = false
    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var showScanner = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var pastedText = ""
    @State private var showTextSheet = false
    @State private var showLinkSheet = false
    @State private var link = ""

    /// La vidéo est la seule source dont le texte s'obtient **en ligne** : elle a donc une
    /// étape de plus que les autres, et elle la fait dans la case, pas dans un écran à part.
    private let youtube = YouTubeImportService()

    /// Quatre cases au départ, et une de plus dès que la dernière est prise. La grille ne
    /// montre donc jamais un mur de vides, et ne se ferme jamais non plus.
    private static let initialSlots = 4

    private var slots: [DeckMaterial] {
        setup.materials
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.deckSetup.materials"),
            subtitle: i18n.t("ios.deckSetup.materials.hint"),
            animatesTitle: true
        ) {
            VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(slots) { material in
                        DeckMaterialSlot(material: material) {
                            open(material)
                        } onRemove: {
                            remove(material)
                        }
                    }
                }

                formatsNote
            }
            .onAppear(perform: seedSlots)
        } footer: {
            VStack(spacing: 8) {
                OnboardingContinueButton(isEnabled: setup.hasMaterials, action: onNext)

                if !setup.hasMaterials {
                    OnboardingHint(text: i18n.t("ios.deckSetup.materials.need"))
                }
            }
        }
        .confirmationDialog(
            i18n.t("ios.deckSetup.materials.add"),
            isPresented: $showChoice,
            titleVisibility: .visible
        ) {
            Button(i18n.t("ios.import.pdf")) { showFileImporter = true }
            Button(i18n.t("ios.import.photo")) { showPhotoPicker = true }
            Button(i18n.t("ios.scanPages")) { showScanner = true }
            Button(i18n.t("ios.import.youtube")) { showLinkSheet = true }
            Button(i18n.t("ios.import.text")) { showTextSheet = true }
            Button(i18n.t("app.common.cancel"), role: .cancel) { target = nil }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, UTType("org.openxmlformats.wordprocessingml.document") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            Task { await ingestFile(result) }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoItems,
            maxSelectionCount: OnDeviceOCR.pageLimit,
            matching: .images
        )
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await ingestPhotos(items) }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentCameraView { images in
                showScanner = false
                Task { await ingestScanned(images) }
            } onCancel: {
                showScanner = false
                target = nil
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showLinkSheet) {
            DeckLinkSheet(link: $link) { value in
                showLinkSheet = false
                Task { await ingestVideo(value) }
            }
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .sheet(isPresented: $showTextSheet) {
            DeckPastedTextSheet(text: $pastedText) { text in
                showTextSheet = false
                applyPastedText(text)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
    }

    private var formatsNote: some View {
        HStack(spacing: MicaboSpacing.sm) {
            ForEach(["doc.fill", "photo.on.rectangle.angled", "doc.richtext", "text.alignleft"], id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            Text(i18n.t("ios.deckSetup.materials.formats"))
                .font(MicaboFont.ui(12, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(.horizontal, MicaboSpacing.xxs)
    }

    // MARK: - Les cases

    private func seedSlots() {
        guard setup.materials.isEmpty else { return }
        setup.materials = (0..<Self.initialSlots).map { _ in DeckMaterial() }
    }

    private func open(_ material: DeckMaterial) {
        guard !material.isBusy else { return }
        target = material
        showChoice = true
    }

    private func remove(_ material: DeckMaterial) {
        material.document = nil
        material.state = .empty
    }

    /// Ajoute une case vide quand la dernière vient d'être prise, pour qu'il y ait toujours
    /// où déposer la suivante sans avoir à chercher un bouton.
    private func growIfNeeded() {
        guard setup.materials.allSatisfy({ !$0.isBusy && $0.state != .empty }) else { return }
        setup.materials.append(DeckMaterial())
    }

    // MARK: - La lecture

    @MainActor
    private func ingestFile(_ result: Result<[URL], Error>) async {
        guard let material = target else { return }
        target = nil

        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result {
                material.state = .failed(error.localizedDescription)
            }
            return
        }

        material.state = .reading
        do {
            let parsed: ImportedDocument
            if url.pathExtension.lowercased() == "docx" {
                parsed = try DocxImportService.extract(from: url)
            } else {
                parsed = try await PDFImportService.extractWithOCR(from: url)
            }
            apply(parsed, to: material)
        } catch {
            material.state = .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func ingestPhotos(_ items: [PhotosPickerItem]) async {
        guard let material = target else { return }
        target = nil
        photoItems = []

        material.state = .reading
        var images: [UIImage] = []
        for item in items.prefix(OnDeviceOCR.pageLimit) {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }

        guard !images.isEmpty else {
            material.state = .failed(i18n.t("ios.err.unreadablePhotos"))
            return
        }
        await read(images, into: material)
    }

    @MainActor
    private func ingestScanned(_ images: [UIImage]) async {
        guard let material = target else { return }
        target = nil
        guard !images.isEmpty else {
            material.state = .empty
            return
        }
        material.state = .reading
        await read(images, into: material)
    }

    @MainActor
    private func read(_ images: [UIImage], into material: DeckMaterial) async {
        do {
            apply(try await PhotoImportService.importImages(images), to: material)
        } catch {
            material.state = .failed(error.localizedDescription)
        }
    }

    /// La vidéo : aperçu, puis transcription, puis vignette. L'aperçu d'abord permet de
    /// refuser un lien mort sans avoir rien téléchargé.
    @MainActor
    private func ingestVideo(_ raw: String) async {
        guard let material = target else { return }
        target = nil

        guard YouTubeLink.isValid(raw) else {
            material.state = .failed(i18n.t("ios.yt.invalidLink"))
            return
        }

        material.state = .reading
        do {
            let video = try await youtube.preview(link: raw)
            let transcript = try await youtube.transcript(link: raw)
            let cover = await youtube.cover(for: video)
            apply(
                YouTubeImportService.document(video: video, transcript: transcript, cover: cover),
                to: material
            )
        } catch {
            material.state = .failed(error.localizedDescription)
        }
        link = ""
    }

    private func applyPastedText(_ text: String) {
        guard let material = target else { return }
        target = nil
        guard let clean = text.nilIfBlank else {
            material.state = .empty
            return
        }
        apply(
            ImportedDocument(
                text: clean,
                pageImages: [],
                coverImage: nil,
                pageCount: 1,
                fileName: i18n.t("ios.deckSetup.materials.pastedName"),
                source: .text,
                extractionNote: nil
            ),
            to: material
        )
        pastedText = ""
    }

    private func apply(_ document: ImportedDocument, to material: DeckMaterial) {
        // Un document illisible est dit tout de suite, sur sa case. Le laisser passer le
        // ferait découvrir trente secondes plus tard, sur l'écran de construction, alors que
        // la fiche aura déjà été écrite sur le peu qu'il en restait.
        guard document.hasUsableText || !document.pageImages.isEmpty else {
            material.state = .failed(i18n.t("ios.deckSetup.materials.unreadable"))
            return
        }
        material.document = document
        material.state = .ready
        growIfNeeded()
        Analytics.track(.importDocumentRead, [
            "source": .text(document.source.rawValue),
            "chars": .number(Double(document.text.count)),
            "deck": .flag(true),
        ])
    }
}

/// Une case : vide, en train de lire, remplie, ou en panne.
private struct DeckMaterialSlot: View {
    @Bindable var material: DeckMaterial
    var onTap: () -> Void
    var onRemove: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                glyph

                if let caption = material.caption {
                    Text(caption)
                        .font(MicaboFont.ui(12, weight: .medium))
                        .foregroundStyle(material.failure == nil ? MicaboColor.ink : MicaboColor.ratingAgain)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                } else {
                    Text(i18n.t("ios.deckSetup.materials.empty"))
                        .font(MicaboFont.ui(12, weight: .medium))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 118)
            .padding(.horizontal, 10)
            .background(background)
            .overlay(border)
            .overlay(alignment: .topTrailing) { removeButton }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .animation(OnboardingMotion.tap, value: material.state)
    }

    @ViewBuilder
    private var glyph: some View {
        switch material.state {
        case .empty:
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
        case .reading:
            ProgressView()
                .controlSize(.regular)
                .tint(MicaboColor.accent)
        case .ready:
            Image(systemName: material.document?.source.systemImage ?? "doc.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(MicaboColor.accent)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(MicaboColor.ratingAgain)
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
            .fill(material.isReady ? MicaboColor.accentSoft : MicaboColor.surface)
    }

    /// Le trait est **pointillé tant que la case est vide**, plein quand elle est prise :
    /// c'est ce qui fait lire la grille comme des emplacements à remplir plutôt que comme
    /// quatre boutons identiques.
    private var border: some View {
        RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
            .strokeBorder(
                material.isReady ? MicaboColor.accent : MicaboColor.strokeStrong,
                style: StrokeStyle(
                    lineWidth: material.isReady ? 1.5 : 1,
                    dash: material.state == .empty ? [5, 4] : []
                )
            )
    }

    @ViewBuilder
    private var removeButton: some View {
        if material.isReady || material.failure != nil {
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk)
                    .frame(width: 22, height: 22)
                    .background(MicaboColor.ink.opacity(0.75), in: Circle())
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
            .padding(7)
            .accessibilityLabel(i18n.t("app.common.delete"))
        }
    }
}

/// Coller un lien de vidéo. Court exprès : c'est un champ et un bouton, pas un écran.
private struct DeckLinkSheet: View {
    @Binding var link: String
    var onDone: (String) -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: MicaboSpacing.md) {
            Text(i18n.t("ios.import.youtube"))
                .font(MicaboFont.ui(19, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            DeckSearchField(
                text: $link,
                placeholder: "https://youtube.com/watch?v=…",
                icon: "link",
                isFocused: $isFocused
            )

            Button(i18n.t("common.continue")) { onDone(link) }
                .buttonStyle(MicaboPrimaryButtonStyle())
                .disabled(!YouTubeLink.isValid(link))

            Spacer(minLength: 0)
        }
        .padding(MicaboSpacing.screen)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .onAppear { isFocused = true }
    }
}

/// Coller du texte : des notes prises sur le téléphone, un extrait de manuel recopié.
private struct DeckPastedTextSheet: View {
    @Binding var text: String
    var onDone: (String) -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(MicaboFont.reading(16, weight: .regular))
                .foregroundStyle(MicaboColor.ink)
                .scrollContentBackground(.hidden)
                .background(MicaboColor.canvas)
                .padding(.horizontal, MicaboSpacing.md)
                .focused($isFocused)
                .navigationTitle(i18n.t("ios.import.text"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(i18n.t("common.continue")) { onDone(text) }
                            .disabled(text.nilIfBlank == nil)
                    }
                }
                .onAppear { isFocused = true }
        }
    }
}
