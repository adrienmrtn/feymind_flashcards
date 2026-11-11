import AVFoundation
import Foundation
import MediaPlayer
import Observation

/// **La leçon lue à voix haute**, sur l'appareil (`docs/supports.md`, « Écouter »).
///
/// `AVSpeechSynthesizer`, dans la voix la plus naturelle que le téléphone a pour la langue de
/// la leçon. Une phrase à la fois : on sait où l'on en est, on change de vitesse sans
/// recommencer le chapitre, on passe au suivant. La session audio est celle d'une lecture
/// parlée : l'écoute continue écran verrouillé, et l'écran de verrouillage montre la leçon
/// avec lecture, pause et chapitre suivant.
@MainActor
@Observable
final class LessonSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    /// Les vitesses proposées.
    static let rates: [Double] = [1, 1.25, 1.5]

    let script: ListeningScript
    let title: String
    let language: String

    private(set) var chapter = 0
    private(set) var line = 0
    private(set) var isPlaying = false
    private(set) var finished = false
    private(set) var rate: Double = 1

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var voice: AVSpeechSynthesisVoice?
    /// L'énoncé en cours : un énoncé annulé (changement de vitesse, de chapitre) ne doit pas
    /// faire avancer la lecture en finissant.
    @ObservationIgnored private var current: AVSpeechUtterance?
    @ObservationIgnored private var commandsInstalled = false

    init(script: ListeningScript, title: String, language: String) {
        self.script = script
        self.title = title
        self.language = language
        super.init()
        synthesizer.delegate = self
        voice = Self.bestVoice(for: language)
    }

    /// La voix « premium » ou « améliorée » de la langue si elle est installée, sinon celle
    /// par défaut.
    static func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let base = String(language.prefix(2))
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let exact = voices.filter { $0.language == language }
        let near = exact.isEmpty ? voices.filter { $0.language.hasPrefix(base) } : exact
        return near.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: language)
    }

    /// La vitesse du synthétiseur pour un multiplicateur : sa vitesse par défaut n'est pas
    /// linéaire, et au-delà de 0,62 la voix devient difficile à suivre.
    static func utteranceRate(for multiplier: Double) -> Float {
        let base = Double(AVSpeechUtteranceDefaultSpeechRate)
        let value = base + (multiplier - 1) * 0.24
        return Float(min(Double(AVSpeechUtteranceMaximumSpeechRate), max(Double(AVSpeechUtteranceMinimumSpeechRate), value)))
    }

    var currentLine: String? {
        guard script.chapters.indices.contains(chapter), script.chapters[chapter].lines.indices.contains(line) else { return nil }
        return script.chapters[chapter].lines[line]
    }

    /// La part de la leçon déjà lue, de 0 à 1.
    var progress: Double {
        let total = script.lineCount
        guard total > 0 else { return 0 }
        let before = script.chapters.prefix(chapter).reduce(0) { $0 + $1.lines.count }
        return Double(before + line) / Double(total)
    }

    // MARK: Lire

    /// Change de vitesse : la phrase en cours reprend à la nouvelle vitesse.
    func setRate(_ value: Double) {
        guard value != rate else { return }
        rate = value
        if isPlaying { restartLine() }
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard !script.chapters.isEmpty else { return }
        if finished {
            finished = false
            chapter = 0
            line = 0
        }
        activateSession()
        installRemoteCommands()
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        } else {
            speakCurrent()
        }
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPlaying = false
        updateNowPlaying()
    }

    func stop() {
        current = nil
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        removeRemoteCommands()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func jump(to index: Int) {
        guard script.chapters.indices.contains(index) else { return }
        chapter = index
        line = 0
        finished = false
        restartLine(forcePlay: true)
    }

    func nextChapter() {
        if chapter + 1 < script.chapters.count {
            jump(to: chapter + 1)
        } else {
            finish()
        }
    }

    func previousChapter() {
        // Au début d'un chapitre, on revient au précédent ; plus loin, au début de celui-ci.
        jump(to: line > 0 ? chapter : max(0, chapter - 1))
    }

    private func restartLine(forcePlay: Bool = false) {
        current = nil
        synthesizer.stopSpeaking(at: .immediate)
        if isPlaying || forcePlay {
            activateSession()
            installRemoteCommands()
            isPlaying = true
            speakCurrent()
        }
        updateNowPlaying()
    }

    private func speakCurrent() {
        guard let text = currentLine else {
            finish()
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = Self.utteranceRate(for: rate)
        // Un titre de chapitre respire un peu plus.
        utterance.postUtteranceDelay = line == 0 ? 0.45 : 0.15
        current = utterance
        synthesizer.speak(utterance)
    }

    private func advance() {
        guard script.chapters.indices.contains(chapter) else { return finish() }
        if line + 1 < script.chapters[chapter].lines.count {
            line += 1
        } else if chapter + 1 < script.chapters.count {
            chapter += 1
            line = 0
        } else {
            return finish()
        }
        speakCurrent()
        updateNowPlaying()
    }

    private func finish() {
        current = nil
        isPlaying = false
        finished = true
        updateNowPlaying()
    }

    // MARK: Le synthétiseur

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let finishedID = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard let current = self.current, ObjectIdentifier(current) == finishedID, self.isPlaying else { return }
            self.advance()
        }
    }

    // MARK: La session audio et l'écran de verrouillage

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [MPMediaItemPropertyTitle: title]
        if script.chapters.indices.contains(chapter) {
            info[MPMediaItemPropertyArtist] = script.chapters[chapter].title
        }
        info[MPMediaItemPropertyAlbumTitle] = "Micabo"
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? rate : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func installRemoteCommands() {
        guard !commandsInstalled else { return }
        commandsInstalled = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.nextChapter() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previousChapter() }
            return .success
        }
    }

    private func removeRemoteCommands() {
        guard commandsInstalled else { return }
        commandsInstalled = false
        let center = MPRemoteCommandCenter.shared()
        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand, center.nextTrackCommand, center.previousTrackCommand] {
            command.removeTarget(nil)
        }
    }
}
