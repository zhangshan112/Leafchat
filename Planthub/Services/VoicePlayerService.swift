import AVFoundation
import Foundation

// MARK: - VoicePlayerService

/// Manages playback of locally stored voice messages.
/// Only one message plays at a time; starting a new one stops the previous.
@Observable
final class VoicePlayerService {

    static let shared = VoicePlayerService()

    /// ID of the message currently loaded (playing or paused).
    private(set) var activeID: String?
    /// Playback progress 0…1 — updated every 50 ms during playback.
    private(set) var progress: Double = 0
    /// Elapsed playback time in seconds.
    private(set) var elapsed: TimeInterval = 0
    private(set) var isPlaying: Bool = false

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    private init() {}

    // MARK: Public API

    func toggle(id: String, url: URL) {
        if activeID == id {
            isPlaying ? pause() : resume()
        } else {
            play(id: id, url: url)
        }
    }

    func stop() {
        player?.stop()
        stopTimer()
        player = nil
        activeID = nil
        isPlaying = false
        progress = 0
        elapsed = 0
    }

    // MARK: Private — playback

    private func play(id: String, url: URL) {
        player?.stop()
        stopTimer()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()

            activeID = id
            progress = 0
            elapsed = 0
            isPlaying = true
            startTimer()
        } catch {
            isPlaying = false
        }
    }

    private func pause() {
        guard let player else { return }
        elapsed = player.currentTime
        player.pause()
        isPlaying = false
        stopTimer()
    }

    private func resume() {
        guard let player else { return }
        player.currentTime = elapsed
        player.play()
        isPlaying = true
        startTimer()
    }

    private func startTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }

            let total = player.duration
            let current = player.currentTime

            self.elapsed = current
            self.progress = total > 0 ? current / total : 0

            if !player.isPlaying && self.isPlaying {
                // Playback finished naturally
                self.isPlaying = false
                self.progress = 0
                self.elapsed = 0
                self.stopTimer()
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }

    private func stopTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
