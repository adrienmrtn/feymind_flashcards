import AVFoundation
import Foundation
import Observation
import Speech

/// **Écouter la réponse de l'élève**, sur l'appareil (`docs/supports.md`, « À voix haute »).
///
/// `SFSpeechRecognizer` dans la langue de la leçon, sur le téléphone quand il sait le faire :
/// rien de ce que l'élève dit ne part sur un serveur. Sur une langue que le téléphone ne
/// reconnaît pas hors ligne, la reconnaissance d'Apple prend le relais, comme pour la dictée
/// du clavier. L'écoute s'arrête d'elle-même après un silence, ou au bout de trente secondes.
@MainActor
@Observable
final class VoiceRecallListener {
    enum State: Equatable {
        case idle
        case listening
        case denied
        case unavailable
    }

    private(set) var state: State = .idle
    private(set) var transcript = ""
    /// Le niveau du micro, de 0 à 1, pour l'onde.
    private(set) var level: Double = 0

    private let recognizer: SFSpeechRecognizer?
    private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var silence: Task<Void, Never>?
    @ObservationIgnored private var onFinish: ((String) -> Void)?

    static let maximumSeconds: Double = 30
    static let silenceSeconds: Double = 1.8

    init(locale: Locale) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    var isListening: Bool { state == .listening }

    /// Les deux autorisations, micro et reconnaissance. Rend `false` et dit pourquoi.
    func prepare() async -> Bool {
        guard await Dictation.requestMicrophone() else {
            state = .denied
            return false
        }
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else {
            state = .denied
            return false
        }
        guard let recognizer, recognizer.isAvailable else {
            state = .unavailable
            return false
        }
        return true
    }

    /// Écoute jusqu'au silence ; `onFinish` reçoit ce qui a été entendu.
    func start(onFinish: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable else {
            state = .unavailable
            return
        }
        stopEngine()
        transcript = ""
        self.onFinish = onFinish

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .unavailable
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let level = Self.level(of: buffer)
            Task { @MainActor in self?.level = level }
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            state = .unavailable
            return
        }

        state = .listening
        scheduleSilence(after: Self.maximumSeconds)
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let heard = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                guard let self, self.state == .listening else { return }
                if let heard {
                    self.transcript = heard
                    self.scheduleSilence(after: Self.silenceSeconds)
                }
                if isFinal || failed { self.finish() }
            }
        }
    }

    /// L'élève a fini de parler : on rend ce qui a été entendu.
    func finish() {
        guard state == .listening else { return }
        stopEngine()
        state = .idle
        let heard = transcript
        let callback = onFinish
        onFinish = nil
        callback?(heard)
    }

    /// Abandonne l'écoute sans rien rendre.
    func cancel() {
        onFinish = nil
        stopEngine()
        if state == .listening { state = .idle }
    }

    private func scheduleSilence(after seconds: Double) {
        silence?.cancel()
        silence = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func stopEngine() {
        silence?.cancel()
        silence = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// La puissance d'un tampon, ramenée entre 0 et 1.
    nonisolated static func level(of buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        let count = Int(buffer.frameLength)
        for index in 0..<count { sum += channel[index] * channel[index] }
        let rms = sqrt(sum / Float(count))
        return min(1, Double(rms) * 12)
    }
}
