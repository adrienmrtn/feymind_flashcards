import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// **Les supports de Home**, et ce qu'ils lisent (`docs/supports.md`). Un appui sur une tuile
/// pose `request` ; ce modificateur ouvre le bon sélecteur, lit le support sur l'appareil et le
/// dépose dans le `LessonComposer`, sur une pastille qui dit où il en est.
///
/// - PDF : un PDF ou un Word (`.docx`), texte puis OCR si la page est une image ; un `.pptx`
///   déposé ici passe par les diapositives.
/// - Diapos : un PowerPoint (`.pptx`), le texte de chaque diapo et ses notes (`SlidesImportService`).
/// - Photo : l'appareil (scan de document) ou la photothèque, OCR sur l'appareil.
/// - Notes manuscrites : le scanner d'abord, puis le même OCR, en mode précis (`OnDeviceOCR`).
/// - Page web : un lien, la page récupérée et nettoyée sur l'appareil (`WebPageImportService`).
/// - YouTube : un lien, sous-titres puis repli serveur (`YouTubeImportService`).
/// - Cours en direct : l'enregistreur, puis la transcription sur l'appareil (`AudioTranscriber`).
/// - Audio : un enregistrement ou un fichier, transcrit de même.
/// - Texte : un texte collé.
/// - Flashcards : un paquet Anki ou un copier-coller Quizlet, qui devient un deck tout de suite,
///   sans génération (`DeckLessonBuilder`) ; le deck s'ouvre ensuite par-dessus Home.
struct LessonImportPickers: ViewModifier {
    let composer: LessonComposer
    @Binding var request: LessonComposer.Kind?

    private enum FileTarget {
        case document
        case slides
        case audio

        var types: [UTType] {
            switch self {
            case .document:
                [.pdf, UTType("org.openxmlformats.wordprocessingml.document") ?? .data] + Self.slideTypes
            case .slides:
                Self.slideTypes
            case .audio:
                [.audio, .mpeg4Audio, .mp3, .wav]
            }
        }

        /// PowerPoint, et Keynote ou l'ancien `.ppt` pour leur dire comment les exporter.
        static var slideTypes: [UTType] {
            [
                UTType("org.openxmlformats.presentationml.presentation"),
                UTType("com.microsoft.powerpoint.ppt"),
                UTType("com.apple.iwork.keynote.key"),
                UTType("com.apple.keynote.key"),
            ].compactMap { $0 }
        }
    }

    @State private var fileTarget: FileTarget = .document
    @State private var showFiles = false
    @State private var showPhotoChoice = false
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    /// La pastille que prennent les images choisies : des photos de cours ou des notes manuscrites.
    @State private var imageKind: LessonComposer.Kind = .photo
    @State private var showScanner = false
    @State private var showAudioChoice = false
    @State private var showRecorder = false
    /// La pastille d'un enregistrement : un cours en direct ou une note vocale.
    @State private var recordingKind: LessonComposer.Kind = .audio
    @State private var showLink = false
    @State private var showWeb = false
    @State private var showText = false
    @State private var showFlashcards = false
    /// Le deck tout juste créé depuis des flashcards, ouvert par-dessus Home.
    @State private var openedDeck: Course?

    private let youtube = YouTubeImportService()
    /// Le paywall de l'import, quand le serveur refuse de lire une vidéo (`import_pro`).
    @State private var paywall: PaywallTrigger?

    func body(content: Content) -> some View {
        content
            .micaboPaywall($paywall)
            .onChange(of: request) { _, kind in
                guard let kind else { return }
                request = nil
                open(kind)
            }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: fileTarget.types, allowsMultipleSelection: false) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                switch fileTarget {
                case .document, .slides: readDocument(url)
                case .audio: readAudioFile(url)
                }
            }
            .confirmationDialog(L10n.t("lesson.import.photo", locale: .resolved()), isPresented: $showPhotoChoice, titleVisibility: .hidden) {
                Button(L10n.t("lesson.import.scan", locale: .resolved())) {
                    // La question système d'abord, et le scanner seulement sur un oui : refusée
                    // dans le scanner, la caméra y laisserait l'impasse de VisionKit.
                    Task {
                        if await CameraAccess.request() {
                            showScanner = true
                        } else {
                            showPhotoPicker = true
                        }
                    }
                }
                Button(L10n.t("lesson.import.library", locale: .resolved())) { showPhotoPicker = true }
            }
            .confirmationDialog(L10n.t("lesson.import.audio", locale: .resolved()), isPresented: $showAudioChoice, titleVisibility: .hidden) {
                Button(L10n.t("lesson.import.record", locale: .resolved())) {
                    recordingKind = .audio
                    showRecorder = true
                }
                Button(L10n.t("lesson.import.audioFile", locale: .resolved())) {
                    fileTarget = .audio
                    showFiles = true
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItems, maxSelectionCount: OnDeviceOCR.pageLimit, matching: .images)
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                photoItems = []
                readPhotos(items)
            }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentCameraView { images in
                    showScanner = false
                    readScanned(images)
                } onCancel: {
                    showScanner = false
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showRecorder) {
                VoiceRecorderSheet(isLecture: recordingKind == .lecture) { url in
                    showRecorder = false
                    readRecording(url)
                }
                .presentationDetents([.height(recordingKind == .lecture ? 470 : 420)])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showLink) {
                LinkEntrySheet { link in
                    showLink = false
                    readVideo(link)
                }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showWeb) {
                WebLinkSheet { link in
                    showWeb = false
                    readWebPage(link)
                }
                .presentationDetents([.height(360), .medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showText) {
                TextEntrySheet { text in
                    showText = false
                    readText(text)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showFlashcards) {
                FlashcardImportSheet { deck in
                    showFlashcards = false
                    // Le temps que la feuille descende : deux présentations ne se croisent pas.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { openedDeck = deck }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $openedDeck) { deck in
                NavigationStack {
                    LessonPathView(course: deck)
                }
            }
    }

    private func open(_ kind: LessonComposer.Kind) {
        // Un paquet de flashcards ne prend pas de place sous la barre : il devient un deck.
        if kind == .flashcards {
            showFlashcards = true
            return
        }
        guard composer.hasRoom else {
            Haptics.warning()
            return
        }
        switch kind {
        case .pdf:
            fileTarget = .document
            showFiles = true
        case .slides:
            fileTarget = .slides
            showFiles = true
        case .photo, .handwriting:
            imageKind = kind
            // Une caméra refusée n'ouvre pas le scanner : VisionKit afficherait sa propre
            // impasse vers les Réglages, que l'App Store a déjà refusée (règle 5.1.1(iv)). On
            // va droit à la photothèque. Des notes manuscrites se scannent d'abord : la page
            // à plat et bien éclairée est ce qui fait lire l'écriture à la main.
            if DocumentCameraView.isSupported, CameraAccess.allowsScanner(CameraAccess.status) {
                if kind == .handwriting {
                    Task {
                        if await CameraAccess.request() {
                            showScanner = true
                        } else {
                            showPhotoPicker = true
                        }
                    }
                } else {
                    showPhotoChoice = true
                }
            } else {
                showPhotoPicker = true
            }
        case .audio:
            showAudioChoice = true
        case .lecture:
            recordingKind = .lecture
            showRecorder = true
        case .youtube:
            showLink = true
        case .web:
            showWeb = true
        case .text:
            showText = true
        case .flashcards:
            break
        }
    }

    // MARK: Lire

    private func readDocument(_ url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension.lowercased()
        let isSlides = ["pptx", "ppt", "pps", "key"].contains(fileExtension)
        guard let id = composer.begin(isSlides ? .slides : .pdf, title: name) else { return }
        Task {
            do {
                let document: ImportedDocument
                if isSlides {
                    document = try SlidesImportService.extract(from: url)
                } else if fileExtension == "docx" {
                    document = try DocxImportService.extract(from: url)
                } else {
                    document = try await PDFImportService.extractWithOCR(from: url)
                }
                composer.finish(id, with: document)
            } catch {
                composer.fail(id, message: error.localizedDescription)
            }
        }
    }

    private var imageTitle: String {
        imageKind == .handwriting
            ? L10n.t("ios.sup.handwriting.name", locale: .resolved())
            : L10n.t("lesson.import.photo", locale: .resolved())
    }

    private func readPhotos(_ items: [PhotosPickerItem]) {
        guard let id = composer.begin(imageKind, title: imageTitle) else { return }
        Task {
            var images: [UIImage] = []
            for item in items.prefix(OnDeviceOCR.pageLimit) {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            await read(images, into: id)
        }
    }

    private func readScanned(_ images: [UIImage]) {
        guard !images.isEmpty,
              let id = composer.begin(imageKind, title: imageTitle) else { return }
        Task { await read(images, into: id) }
    }

    private func read(_ images: [UIImage], into id: UUID) async {
        do {
            var document = try await PhotoImportService.importImages(images)
            if imageKind == .handwriting {
                document.fileName = imageTitle
            }
            composer.finish(id, with: document)
        } catch {
            composer.fail(id, message: error.localizedDescription)
        }
    }

    /// Un fichier audio choisi dans Fichiers : copié chez l'app d'abord, la transcription
    /// dure plus longtemps que l'accès qu'on nous prête.
    private func readAudioFile(_ url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("micabo-audio-\(UUID().uuidString)")
            .appendingPathExtension(url.pathExtension.isEmpty ? "m4a" : url.pathExtension)
        do {
            try FileManager.default.copyItem(at: url, to: copy)
        } catch {
            if let id = composer.begin(.audio, title: name) {
                composer.fail(id, message: AudioTranscriber.Failure.unreadable.errorDescription ?? "")
            }
            return
        }
        transcribe(copy, title: name, kind: .audio)
    }

    private func readRecording(_ url: URL) {
        let lecture = recordingKind == .lecture
        transcribe(
            url,
            title: lecture
                ? L10n.t("ios.sup.lecture.name", locale: .resolved())
                : L10n.t("lesson.import.recordingName", locale: .resolved()),
            kind: lecture ? .lecture : .audio
        )
    }

    private func transcribe(_ url: URL, title: String, kind: LessonComposer.Kind) {
        guard let id = composer.begin(kind, title: title) else { return }
        Task {
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                let text = try await AudioTranscriber.transcribe(url, language: OnboardingPreferences.contentLanguage)
                composer.finish(id, with: ImportedDocument(
                    text: text,
                    pageImages: [],
                    coverImage: nil,
                    pageCount: 1,
                    fileName: title,
                    source: .text,
                    extractionNote: nil
                ))
            } catch {
                composer.fail(id, message: error.localizedDescription)
            }
        }
    }

    private func readVideo(_ link: String) {
        guard YouTubeLink.isValid(link) else {
            if let id = composer.begin(.youtube, title: "YouTube") {
                composer.fail(id, message: L10n.t("ios.yt.invalidLink", locale: .resolved()))
            }
            return
        }
        guard let id = composer.begin(.youtube, title: "YouTube") else { return }
        Task {
            do {
                let video = try await youtube.preview(link: link)
                let transcript = try await youtube.transcript(link: link)
                let cover = await youtube.cover(for: video)
                composer.finish(id, with: YouTubeImportService.document(video: video, transcript: transcript, cover: cover))
            } catch YouTubeImportError.importPro {
                // Un refus commercial, pas une panne : la case le dit, et le paywall de
                // l'import s'ouvre, comme pour un PDF importé sans abonnement.
                composer.fail(id, message: YouTubeImportError.importPro.localizedDescription)
                paywall = .generateCourse
            } catch {
                composer.fail(id, message: error.localizedDescription)
            }
        }
    }

    /// Une page web. Un lien YouTube collé ici part par le support YouTube, qui lit les
    /// sous-titres au lieu de la page du lecteur.
    private func readWebPage(_ link: String) {
        if YouTubeLink.isValid(link) {
            readVideo(link)
            return
        }
        let host = WebPageImportService.url(from: link)?.host?.replacingOccurrences(of: "www.", with: "")
        guard let id = composer.begin(.web, title: host ?? L10n.t("ios.sup.source.web", locale: .resolved())) else { return }
        Task {
            do {
                composer.finish(id, with: try await WebPageImportService.read(link))
            } catch {
                composer.fail(id, message: error.localizedDescription)
            }
        }
    }

    private func readText(_ text: String) {
        guard let clean = text.nilIfBlank,
              let id = composer.begin(.text, title: L10n.t("lesson.import.pastedName", locale: .resolved())) else { return }
        composer.finish(id, with: ImportedDocument(
            text: clean,
            pageImages: [],
            coverImage: nil,
            pageCount: 1,
            fileName: L10n.t("lesson.import.pastedName", locale: .resolved()),
            source: .text,
            extractionNote: nil
        ))
    }
}

extension View {
    func lessonImportPickers(_ composer: LessonComposer, request: Binding<LessonComposer.Kind?>) -> some View {
        modifier(LessonImportPickers(composer: composer, request: request))
    }
}

// MARK: - Les feuilles

/// Coller un lien YouTube.
struct LinkEntrySheet: View {
    let onDone: (String) -> Void

    @State private var link = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                MicaboIconView(icon: .link, size: 40)
                Text(L10n.t("lesson.import.youtubeTitle", locale: .resolved()))
                    .font(MicaboFont.subtitle)
                    .foregroundStyle(MicaboColor.ink)
            }
            TextField(L10n.t("lesson.import.youtubePlaceholder", locale: .resolved()), text: $link)
                .font(MicaboFont.ui(17, weight: .medium))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .padding(16)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
            HStack(spacing: 10) {
                Button(L10n.t("lesson.import.paste", locale: .resolved())) {
                    if let pasted = UIPasteboard.general.string { link = pasted }
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
                Button(L10n.t("lesson.import.add", locale: .resolved())) { onDone(link) }
                    .buttonStyle(LessonPrimaryButtonStyle(enabled: link.nilIfBlank != nil))
                    .disabled(link.nilIfBlank == nil)
            }
        }
        .padding(MicaboSpacing.screen)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .onAppear { focused = true }
    }
}

/// Coller un texte.
struct TextEntrySheet: View {
    let onDone: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                MicaboIconView(icon: .text, size: 40)
                Text(L10n.t("lesson.import.textTitle", locale: .resolved()))
                    .font(MicaboFont.subtitle)
                    .foregroundStyle(MicaboColor.ink)
                Spacer()
                Button(L10n.t("lesson.import.add", locale: .resolved())) { onDone(text) }
                    .font(MicaboFont.ui(17, weight: .heavy))
                    .foregroundStyle(text.nilIfBlank == nil ? MicaboColor.inkTertiary : MicaboColor.accent)
                    .disabled(text.nilIfBlank == nil)
            }
            TextEditor(text: $text)
                .font(MicaboFont.notes)
                .scrollContentBackground(.hidden)
                .focused($focused)
                .padding(12)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(L10n.t("lesson.import.textPlaceholder", locale: .resolved()))
                            .font(MicaboFont.notes)
                            .foregroundStyle(MicaboColor.inkTertiary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(MicaboSpacing.screen)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .onAppear { focused = true }
    }
}

/// Enregistrer un cours ou une note vocale. Un cours en direct dit en plus où poser le
/// téléphone : près du professeur, écran verrouillé s'il le faut.
struct VoiceRecorderSheet: View {
    var isLecture = false
    let onDone: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = VoiceRecorder()

    var body: some View {
        VStack(spacing: 18) {
            Text(isLecture
                ? L10n.t("ios.sup.lecture.title", locale: .resolved())
                : L10n.t("lesson.import.recordTitle", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            if isLecture {
                Text(L10n.t("ios.sup.lecture.tip", locale: .resolved()))
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(elapsed(at: timeline.date))
                    .font(MicaboFont.number(44))
                    .foregroundStyle(recorder.isRecording ? MicaboColor.wrong : MicaboColor.ink)
                    .monospacedDigit()
            }

            Text(L10n.t("lesson.import.recordLimit", locale: .resolved()))
                .font(MicaboFont.ui(14, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)

            if case .failed(let message) = recorder.state {
                Text(message)
                    .font(MicaboFont.ui(14, weight: .bold))
                    .foregroundStyle(MicaboColor.wrongInk)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                if recorder.isRecording {
                    recorder.stop()
                } else {
                    Task { await recorder.start() }
                }
            } label: {
                ZStack {
                    Circle().fill(MicaboColor.wrong).frame(width: 76, height: 76)
                    if recorder.isRecording {
                        RoundedRectangle(cornerRadius: 6).fill(MicaboColor.onInk).frame(width: 26, height: 26)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(MicaboColor.onInk)
                    }
                }
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
            .accessibilityLabel(Text(recorder.isRecording
                ? L10n.t("lesson.import.recordStop", locale: .resolved())
                : L10n.t("lesson.import.record", locale: .resolved())))

            Button(L10n.t("lesson.create.cancel", locale: .resolved())) {
                recorder.discard()
                dismiss()
            }
            .font(MicaboFont.ui(16, weight: .bold))
            .foregroundStyle(MicaboColor.inkSecondary)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MicaboSpacing.screen)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .onChange(of: recorder.state) { _, state in
            if case .finished(let url) = state { onDone(url) }
        }
    }

    private func elapsed(at date: Date) -> String {
        guard case .recording(let since) = recorder.state else { return "0:00" }
        let seconds = max(0, Int(date.timeIntervalSince(since)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
