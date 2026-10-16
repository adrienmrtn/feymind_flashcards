import AVFoundation
import Foundation
import Observation

/// **Enregistrer un cours dans l'app** : un fichier `.m4a` dans le dossier temporaire, arrêté
/// à quatre-vingt-dix minutes. La transcription vient après, sur le même fichier.
@MainActor
@Observable
final class VoiceRecorder: NSObject, AVAudioRecorderDelegate {
    enum State: Equatable {
        case idle
        case recording(since: Date)
        case finished(URL)
        case failed(String)
    }

    private(set) var state: State = .idle
    private var recorder: AVAudioRecorder?

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    /// Demande le micro, puis enregistre.
    func start() async {
        guard await Dictation.requestMicrophone() else {
            state = .failed(L10n.t("lesson.audio.micDenied", locale: .resolved()))
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("micabo-recording-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            guard recorder.record(forDuration: AudioTranscriber.maximumDuration) else {
                state = .failed(L10n.t("lesson.audio.unreadable", locale: .resolved()))
                return
            }
            self.recorder = recorder
            state = .recording(since: Date())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
        guard let recorder else { return }
        recorder.stop()
        finish(recorder.url)
    }

    /// Abandonne l'enregistrement et efface le fichier.
    func discard() {
        recorder?.stop()
        if let url = recorder?.url { try? FileManager.default.removeItem(at: url) }
        recorder = nil
        state = .idle
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func finish(_ url: URL) {
        recorder = nil
        state = .finished(url)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // L'enregistrement s'arrête seul à quatre-vingt-dix minutes.
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url = recorder.url
        Task { @MainActor in
            guard self.isRecording else { return }
            self.finish(url)
        }
    }
}
