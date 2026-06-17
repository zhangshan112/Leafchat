import AVFoundation
import Foundation

// MARK: - VoiceRecordingService

/// Manages microphone permission, recording lifecycle, and temp audio file output.
/// Recorded files are written to ChatAudio_Temp/; callers move them to permanent storage.
@Observable
final class VoiceRecordingService {

    enum RecordingState {
        case idle
        case recording
    }

    static let shared = VoiceRecordingService()

    private(set) var recordingState: RecordingState = .idle
    /// Elapsed seconds — updated every 0.1 s during recording.
    private(set) var duration: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentOutputURL: URL?

    var isRecording: Bool { recordingState == .recording }

    private init() {}

    // MARK: Public API

    /// Requests microphone permission (if needed), then starts recording.
    /// Returns `false` when permission is denied.
    func startRecording() async -> Bool {
        let granted = await requestMicrophonePermission()
        guard granted else { return false }
        await MainActor.run { beginRecording() }
        return true
    }

    /// Stops recording and returns the temp URL.
    /// Returns `nil` when the recording is shorter than 1 second (discards file).
    func stopRecording() -> URL? {
        guard recordingState == .recording else { return nil }
        recorder?.stop()
        stopTimer()
        recordingState = .idle

        guard duration >= 1.0 else {
            cancelAndCleanup()
            return nil
        }

        let url = currentOutputURL
        currentOutputURL = nil
        duration = 0
        deactivateSession()
        return url
    }

    /// Stops and discards the current recording without returning a file.
    func cancelRecording() {
        recorder?.stop()
        stopTimer()
        cancelAndCleanup()
        recordingState = .idle
        duration = 0
        deactivateSession()
    }

    // MARK: Private — recording lifecycle

    private func beginRecording() {
        let url = makeOutputURL()
        currentOutputURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()

            recordingState = .recording
            duration = 0
            startTimer()
        } catch {
            recordingState = .idle
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.recordingState == .recording else { return }
            self.duration += 0.1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func cancelAndCleanup() {
        if let url = currentOutputURL {
            try? FileManager.default.removeItem(at: url)
            currentOutputURL = nil
        }
        duration = 0
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Private — file management

    private func makeOutputURL() -> URL {
        let dir = tempAudioDirectory()
        let filename = "\(UUID().uuidString).m4a"
        return dir.appendingPathComponent(filename)
    }

    private func tempAudioDirectory() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ChatAudio_Temp", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: Private — permission

    private func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}
