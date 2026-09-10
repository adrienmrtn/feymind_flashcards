import AVFoundation
import Foundation
import Observation
import Speech

/// **Dicter une explication.**
///
/// La reconnaissance vocale du téléphone transcrit en direct, et le texte reste modifiable :
/// une transcription qui écorche un terme technique ferait perdre des points sur un mot que
/// l'étudiant a dit juste. C'est le pendant de la dictée du site, avec `SFSpeechRecognizer` à
/// la place de celle du navigateur.
///
/// Les deux autorisations - micro et reconnaissance - se demandent **avant** d'ouvrir la
/// copie, dans la question « as-tu un micro ? » : une autorisation demandée au milieu de
/// l'épreuve arrête le chronomètre dans la tête de l'étudiant.
@Observable
@MainActor
final class Dictation {
    enum Availability {
        case unknown
        case ready
        /// Le téléphone ne sait pas transcrire dans cette langue, ou pas hors ligne.
        case unavailable
        /// L'étudiant a refusé le micro ou la reconnaissance.
        case denied
    }

    private(set) var availability: Availability = .unknown
    private(set) var isListening = false
    /// **Quelle question écoute.** Une copie porte plusieurs questions orales et une seule
    /// dictée : sans cette identité, toutes les questions affichaient « Arrêter » dès qu'on
    /// dictait sur l'une d'elles, et il n'y avait plus moyen de savoir où partait la voix.
    private(set) var listeningTo: String?

    private let recognizer: SFSpeechRecognizer?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Ce qui était écrit avant de reprendre la dictée, pour ne pas l'effacer.
    private var committed = ""
    private var onText: ((String) -> Void)?

    /// `nonisolated` : la vue crée sa dictée dans un initialiseur de propriété, hors acteur.
    nonisolated init(locale: Locale = UiLocale.resolved().foundation) {
        recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()
    }

    /// Demande le micro et la reconnaissance, pour de vrai. Rend `true` quand les deux sont
    /// accordés et qu'on saura transcrire.
    func prepare() async -> Bool {
        let microphone = await Self.requestMicrophone()
        guard microphone else {
            availability = .denied
            return false
        }

        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else {
            availability = .denied
            return false
        }

        guard let recognizer, recognizer.isAvailable else {
            availability = .unavailable
            return false
        }
        availability = .ready
        return true
    }

    /// Le micro seul. Ce qui compte ici est l'autorisation, pas l'enregistrement.
    static func requestMicrophone() async -> Bool {
        if #available(iOS 17, *) {
            return await AVAudioApplication.requestRecordPermission()
        }
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
    }

    /// Vrai quand c'est **cette** question qui écoute.
    func isListening(to id: String) -> Bool {
        isListening && listeningTo == id
    }

    /// Démarre ou arrête la dictée sur une question. `current` est le texte déjà écrit : la
    /// dictée s'y ajoute.
    ///
    /// Dicter sur une autre question **déplace** le micro : on ne peut pas parler à deux
    /// endroits, et laisser la première écouter en fond enverrait la suite de la phrase dans
    /// la mauvaise réponse.
    func toggle(id: String, current: String, onText: @escaping (String) -> Void) {
        if isListening, listeningTo == id {
            stop()
            return
        }
        if isListening { stop() }
        start(id: id, current: current, onText: onText)
    }

    private func start(id: String, current: String, onText: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable else {
            availability = .unavailable
            return
        }
        committed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        self.onText = onText

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            availability = .unavailable
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            availability = .unavailable
            return
        }

        isListening = true
        listeningTo = id
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let heard = result.bestTranscription.formattedString
                    let text = [self.committed, heard].filter { !$0.isEmpty }.joined(separator: " ")
                    self.onText?(text)
                    if result.isFinal { self.committed = text }
                }
                if error != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }
    }

    func stop() {
        guard isListening || engine.isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        listeningTo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
