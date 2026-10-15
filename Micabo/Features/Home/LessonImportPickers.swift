import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// **Les cinq imports de Home**, et ce qu'ils lisent. Un appui sur une icône pose
/// `request` ; ce modificateur ouvre le bon sélecteur, lit le support sur l'appareil et le
/// dépose dans le `LessonComposer`, sur une pastille qui dit où il en est.
///
/// - PDF : un PDF ou un Word (`.docx`), texte puis OCR si la page est une image.
/// - Photo : l'appareil (scan de document) ou la photothèque, OCR sur l'appareil.
/// - Audio : un fichier ou un enregistrement, transcrit sur l'appareil (`AudioTranscriber`).
/// - YouTube : un lien, sous-titres puis repli serveur (`YouTubeImportService`).
/// - Texte : un texte collé.
struct LessonImportPickers: ViewModifier {
    let composer: LessonComposer
    @Binding var request: LessonComposer.Kind?

    private enum FileTarget {
        case document
        case audio

        var types: [UTType] {
            switch self {
            case .document:
                [.pdf, UTType("org.openxmlformats.wordprocessingml.document") ?? .data]
            case .audio:
                [.audio, .mpeg4Audio, .mp3, .wav]
            }
        }
    }

    @State private var fileTarget: FileTarget = .document
    @State private var showFiles = false
    @State private var showPhotoChoice = false
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showScanner = false
    @State private var showAudioChoice = false
    @State private var showRecorder = false
    @State private var showLink = false
    @State private var showText = false

    private let youtube = YouTubeImportService()

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, kind in
                guard let kind else { return }
                request = nil
                open(kind)
            }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: fileTarget.types, allowsMultipleSelection: false) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                switch fileTarget {
                case .document: readDocument(url)
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
                Button(L10n.t("lesson.import.record", locale: .resolved())) { showRecorder = true }
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
                VoiceRecorderSheet { url in
                    showRecorder = false
                    readRecording(url)
                }
                .presentationDetents([.height(420)])
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
            .sheet(isPresented: $showText) {
                TextEntrySheet { text in
                    showText = false
                    readText(text)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }

    private func open(_ kind: LessonComposer.Kind) {
        guard composer.hasRoom else {
            Haptics.warning()
            return
        }
        switch kind {
        case .pdf:
            fileTarget = .document
            showFiles = true
        case .photo:
            // Une caméra refusée n'ouvre pas le scanner : VisionKit afficherait sa propre
            // impasse vers les Réglages, que l'App Store a déjà refusée (règle 5.1.1(iv)). On
            // va droit à la photothèque.
            if DocumentCameraView.isSupported, CameraAccess.allowsScanner(CameraAccess.status) {
                showPhotoChoice = true
            } else {
                showPhotoPicker = true
            }
        case .audio:
            showAudioChoice = true
        case .youtube:
            showLink = true
        case .text:
            showText = true
        }
    }

    // MARK: Lire

    private func readDocument(_ url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        guard let id = composer.begin(.pdf, title: name) else { return }
        Task {
            do {
                let document = url.pathExtension.lowercased() == "docx"
                    ? try DocxImportService.extract(from: url)
                    : try await PDFImportService.extractWithOCR(from: url)
                composer.finish(id, with: document)
            } catch {
                composer.fail(id, message: error.localizedDescription)
            }
        }
    }

    private func readPhotos(_ items: [PhotosPickerItem]) {
        guard let id = composer.begin(.photo, title: L10n.t("lesson.import.photo", locale: .resolved())) else { return }
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
              let id = composer.begin(.photo, title: L10n.t("lesson.import.photo", locale: .resolved())) else { return }
        Task { await read(images, into: id) }
    }

    private func read(_ images: [UIImage], into id: UUID) async {
        do {
            composer.finish(id, with: try await PhotoImportService.importImages(images))
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
        transcribe(copy, title: name)
    }

    private func readRecording(_ url: URL) {
        transcribe(url, title: L10n.t("lesson.import.recordingName", locale: .resolved()))
    }

    private func transcribe(_ url: URL, title: String) {
        guard let id = composer.begin(.audio, title: title) else { return }
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

/// Enregistrer un cours ou une note vocale.
struct VoiceRecorderSheet: View {
    let onDone: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = VoiceRecorder()

    var body: some View {
        VStack(spacing: 18) {
            Text(L10n.t("lesson.import.recordTitle", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .padding(.top, 24)

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
