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
            animatesTitle: true
        ) {
            VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(Array(slots.enumerated()), id: \.element.id) { rank, material in
                        DeckMaterialSlot(material: material, rank: rank) {
                            open(material)
                        } onRemove: {
                            remove(material)
                        }
                    }
                }
            }
            .onAppear(perform: seedSlots)
        } footer: {
            OnboardingContinueButton(isEnabled: setup.hasMaterials, action: onNext)
        }
        // **Une languette, pas une feuille système.**
        //
        // C'était un `confirmationDialog` : cinq lignes de texte bleu empilées, au style
        // d'iOS et non au nôtre, sans une icône pour distinguer « une photo » de « scanner
        // des pages ». Cinq sources qui ne se ressemblent pas, présentées comme cinq
        // variantes de la même chose. La languette leur donne chacune sa tuile et sa phrase,
        // et c'est la même grammaire de rangées que le reste de l'app.
        .sheet(isPresented: $showChoice, onDismiss: { if !isPicking { target = nil } }) {
            DeckSourcePickerSheet { source in
                showChoice = false
                choose(source)
            }
            // Trois cent quatre-vingt-douze points coupaient la dernière rangée et
            // serraient le titre contre la poignée : le titre, cinq rangées de soixante-quatre
            // et les marges font quatre cent soixante-dix, plus ce que le téléphone prend en
            // bas. Le détent est mesuré, pas estimé.
            .presentationDetents([.height(504)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
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

    /// Vrai entre la fermeture de la languette et l'ouverture du sélecteur choisi : sans ça,
    /// la fermeture effacerait la case visée juste avant qu'on y dépose le document.
    private var isPicking: Bool {
        showFileImporter || showPhotoPicker || showScanner || showLinkSheet || showTextSheet
    }

    private func choose(_ source: DeckSourcePickerSheet.Source) {
        switch source {
        case .document: showFileImporter = true
        case .photos: showPhotoPicker = true
        case .scan: showScanner = true
        case .video: showLinkSheet = true
        case .text: showTextSheet = true
        }
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
    /// Le rang dans la grille : règle l'entrée en cascade.
    var rank: Int = 0
    var onTap: () -> Void
    var onRemove: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// La case qui vient d'être remplie se soulève et retombe : c'est ce qui dit « reçu »
    /// avant même qu'on ait lu le nom du fichier.
    @State private var pop = false

    var body: some View {
        slot
            .scaleEffect(pop ? 1.06 : 1)
            .onboardingAppear(index: 4 + rank, stagger: OnboardingMotion.rowStagger)
            .onChange(of: material.isReady) { _, ready in
                guard ready else { return }
                Haptics.success()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { pop = true }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.65)) { pop = false }
                }
            }
    }

    private var slot: some View {
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

/// **La languette qui demande d'où vient le support.**
///
/// Cinq sources, cinq tuiles, une phrase chacune. Elle remplace une feuille d'action système
/// dont les cinq lignes se ressemblaient toutes : « Une photo » et « Scanner des pages » sont
/// deux gestes différents — l'un prend une image qu'on a déjà, l'autre ouvre l'appareil photo
/// et redresse les pages — et rien dans un empilement de texte bleu ne le disait.
///
/// La hauteur est fixée plutôt que laissée au contenu : une languette qui s'ouvre à mi-écran
/// puis se recale sur sa taille réelle fait sauter les rangées sous le doigt qui vise déjà.
struct DeckSourcePickerSheet: View {
    enum Source {
        case document
        case photos
        case scan
        case video
        case text
    }

    var onPick: (Source) -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.md) {
            Text(i18n.t("ios.deckSetup.materials.add"))
                .font(MicaboFont.ui(20, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(MicaboColor.ink)
                .padding(.horizontal, MicaboSpacing.xxs)

            MicaboRowGroup(rows: [
                row(.document, symbol: "doc.fill", title: "ios.import.pdf", tint: MicaboColor.accent),
                row(.photos, symbol: "photo.on.rectangle.angled", title: "ios.import.photo", tint: MicaboColor.info),
                row(.scan, symbol: "doc.viewfinder", title: "ios.scanPages", tint: MicaboColor.positive),
                row(.video, symbol: "play.rectangle.fill", title: "ios.import.youtube", tint: MicaboColor.flame),
                row(.text, symbol: "text.alignleft", title: "ios.import.text", tint: MicaboColor.caution),
            ])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MicaboSpacing.screen)
        // Vingt-huit en haut pour dégager la poignée, qui se pose à huit du bord et passait
        // sinon dans le titre.
        .padding(.top, 28)
        .padding(.bottom, MicaboSpacing.lg)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(MicaboColor.canvas.ignoresSafeArea())
    }

    private func row(_ source: Source, symbol: String, title: String, tint: Color) -> MicaboRow {
        MicaboRow(
            tile: MicaboTile(
                glyph: .symbol(symbol),
                background: tint.lightened(by: 0.86),
                tint: tint
            ),
            title: i18n.t(title),
            accessory: .chevron,
            action: { onPick(source) }
        )
    }
}
