import AVFoundation
import Foundation
import Speech

/// **Un enregistrement devient du texte, sur le téléphone.** Voir `docs/refonte-parcours.md` § 3.
///
/// Un mémo vocal, un `.m4a`, un `.mp3`, un `.wav`, ou ce qu'on vient d'enregistrer dans l'app :
/// rien ne part sur un serveur, seul le texte servira à écrire la leçon. Sur iOS 26, la
/// transcription passe par `SpeechTranscriber`, fait pour les longs fichiers ; avant, par
/// `SFSpeechRecognizer` en mode local.
///
/// Quatre-vingt-dix minutes au plus : au-delà, c'est un cours entier de plus que ce qu'une leçon
/// peut tenir, et une transcription sur l'appareil de cette longueur fait chauffer le téléphone.
enum AudioTranscriber {
    static let maximumDuration: TimeInterval = 90 * 60
    /// En dessous, il n'y a pas de quoi écrire une leçon.
    static let minimumCharacters = 40

    enum Failure: LocalizedError, Equatable {
        case denied
        case unavailable
        case tooLong
        case unreadable
        case empty

        var errorDescription: String? {
            switch self {
            case .denied: L10n.t("lesson.audio.denied", locale: .resolved())
            case .unavailable: L10n.t("lesson.audio.unavailable", locale: .resolved())
            case .tooLong: L10n.t("lesson.audio.tooLong", locale: .resolved())
            case .unreadable: L10n.t("lesson.audio.unreadable", locale: .resolved())
            case .empty: L10n.t("lesson.audio.empty", locale: .resolved())
            }
        }
    }

    /// La langue dans laquelle on écoute : celle de l'élève, avec la région que la
    /// reconnaissance attend.
    static func locale(for language: ContentLanguage) -> Locale {
        let identifiers: [String: String] = [
            "fr": "fr-FR", "en": "en-US", "de": "de-DE", "it": "it-IT", "es": "es-ES", "pt": "pt-BR",
            "cs": "cs-CZ", "nl": "nl-NL", "el": "el-GR", "hu": "hu-HU", "pl": "pl-PL", "ro": "ro-RO",
            "sv": "sv-SE", "tr": "tr-TR",
        ]
        return Locale(identifier: identifiers[language.rawValue] ?? language.rawValue)
    }

    /// La durée d'un fichier, ou `nil` s'il ne se lit pas.
    static func duration(of url: URL) async -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        guard let time = try? await asset.load(.duration) else { return nil }
        let seconds = time.seconds
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }

    /// Transcrit un fichier audio. Le fichier doit être lisible par l'app (copié dans son
    /// dossier, ou sous accès de sécurité ouvert par l'appelant).
    static func transcribe(_ url: URL, language: ContentLanguage) async throws -> String {
        guard let duration = await duration(of: url) else { throw Failure.unreadable }
        guard duration <= maximumDuration + 1 else { throw Failure.tooLong }

        let locale = locale(for: language)
        let text: String
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), let modern = try? await transcribeWithAnalyzer(url, locale: locale) {
            text = modern
        } else {
            text = try await transcribeWithRecognizer(url, locale: locale)
        }
        #else
        text = try await transcribeWithRecognizer(url, locale: locale)
        #endif

        let clean = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard clean.count >= minimumCharacters else { throw Failure.empty }
        return clean
    }

    // MARK: - iOS 17 à 25

    private static func transcribeWithRecognizer(_ url: URL, locale: Locale) async throws -> String {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { throw Failure.denied }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw Failure.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        // Sur l'appareil quand il sait le faire : sinon la reconnaissance d'Apple coupe à une
        // minute, ce qui ne transcrit pas un cours.
        guard recognizer.supportsOnDeviceRecognition else { throw Failure.unavailable }
        request.requiresOnDeviceRecognition = true

        let box = RecognitionBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                box.task = recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal {
                        box.finish(continuation, with: .success(result.bestTranscription.formattedString))
                    } else if let error {
                        box.finish(continuation, with: .failure(error))
                    }
                }
            }
        } onCancel: {
            box.task?.cancel()
        }
    }

    /// Une reconnaissance ne doit rendre sa réponse qu'une fois : un résultat final peut être
    /// suivi d'une erreur de fin de flux.
    private final class RecognitionBox: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        var task: SFSpeechRecognitionTask?

        func finish(_ continuation: CheckedContinuation<String, Error>, with result: Result<String, Error>) {
            lock.lock()
            defer { lock.unlock() }
            guard !done else { return }
            done = true
            continuation.resume(with: result)
        }
    }

    // MARK: - iOS 26

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private static func transcribeWithAnalyzer(_ url: URL, locale: Locale) async throws -> String {
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw Failure.unavailable
        }
        let transcriber = SpeechTranscriber(
            locale: supported,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installation.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let file = try AVAudioFile(forReading: url)
        async let collected: String = transcriber.results.reduce(into: "") { text, result in
            if result.isFinal {
                text += String(result.text.characters) + " "
            }
        }
        if let last = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: last)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return try await collected
    }
    #endif
}
