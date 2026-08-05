import AVFoundation
import Foundation
import Observation

/// Lit les segments du podcast à la suite, comme une seule piste.
@Observable
@MainActor
final class PodcastPlayer {
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var currentIndex = 0
    private(set) var currentTime: TimeInterval = 0
    private(set) var segmentDuration: TimeInterval = 0
    private(set) var errorMessage: String?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var segments: [PodcastSegment] = []

    var currentSegment: PodcastSegment? {
        segments.indices.contains(currentIndex) ? segments[currentIndex] : nil
    }

    var overallProgress: Double {
        guard !segments.isEmpty else { return 0 }
        let completed = segments.prefix(currentIndex).reduce(0.0) { $0 + Double($1.durationMs) / 1000 }
        let total = segments.reduce(0.0) { $0 + Double($1.durationMs) / 1000 }
        guard total > 0 else { return 0 }
        return min(1, (completed + currentTime) / total)
    }

    var overallLabel: String {
        let total = segments.reduce(0) { $0 + $1.durationMs } / 1000
        let elapsed = segments.prefix(currentIndex).reduce(0) { $0 + $1.durationMs } / 1000
            + Int(currentTime)
        return "\(format(elapsed)) / \(format(total))"
    }

    func load(_ podcast: CoursePodcast) {
        stop()
        segments = podcast.segments
        currentIndex = 0
        errorMessage = nil
        prepareCurrent()
    }

    func toggle() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        guard !segments.isEmpty else { return }
        activateSession()
        if player == nil { prepareCurrent() }
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        removeObservers()
        player?.pause()
        player = nil
        isPlaying = false
        isBuffering = false
        currentTime = 0
        segmentDuration = 0
    }

    func skipForward() {
        guard currentIndex + 1 < segments.count else {
            pause()
            return
        }
        currentIndex += 1
        prepareCurrent(autoplay: isPlaying)
    }

    func skipBackward() {
        if currentTime > 2 {
            player?.seek(to: .zero)
            currentTime = 0
            return
        }
        guard currentIndex > 0 else {
            player?.seek(to: .zero)
            currentTime = 0
            return
        }
        currentIndex -= 1
        prepareCurrent(autoplay: isPlaying)
    }

    func jump(to index: Int) {
        guard segments.indices.contains(index) else { return }
        currentIndex = index
        prepareCurrent(autoplay: isPlaying)
    }

    // MARK: - Interne

    private func prepareCurrent(autoplay: Bool = false) {
        removeObservers()
        guard let segment = currentSegment, let url = URL(string: segment.audioURL) else {
            errorMessage = "Segment audio introuvable."
            return
        }

        isBuffering = true
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        segmentDuration = Double(segment.durationMs) / 1000
        currentTime = 0

        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                if let duration = newPlayer.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
                    self.segmentDuration = duration
                }
                self.isBuffering = newPlayer.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.advanceAfterSegment()
            }
        }

        if autoplay {
            newPlayer.play()
            isPlaying = true
        }
        isBuffering = false
    }

    private func advanceAfterSegment() {
        if currentIndex + 1 < segments.count {
            currentIndex += 1
            prepareCurrent(autoplay: true)
        } else {
            isPlaying = false
            currentTime = segmentDuration
        }
    }

    private func removeObservers() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
    }

    private func format(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }
}
