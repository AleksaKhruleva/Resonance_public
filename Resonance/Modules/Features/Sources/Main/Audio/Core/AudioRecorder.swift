import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AudioRecorder {

    // MARK: - Internal Types

    enum State: Equatable {
        case idle
        case recording
        case recorded
        case permissionDenied
        case failed
    }

    // MARK: - Properties

    private(set) var state: State = .idle
    private(set) var recordedFileURL: URL?
    private(set) var duration: TimeInterval = 0
    private(set) var remainingSeconds: Int

    let maxDuration: Int

    private var audioRecorder: AVAudioRecorder?
    private var activeFileURL: URL?
    private var recordingStartedAt: Date?
    private var timer: Timer?
    private var isPreparingRecording = false

    private let fileManager: FileManager

    var hasRecording: Bool {
        recordedFileURL != nil
    }

    // MARK: - Internal Init

    init(
        maxDuration: Int = 60,
        fileManager: FileManager = .default,
        recordedFileURL: URL? = nil,
        duration: TimeInterval = 0
    ) {
        self.maxDuration = maxDuration
        self.remainingSeconds = maxDuration
        self.fileManager = fileManager

        if let recordedFileURL, fileManager.fileExists(atPath: recordedFileURL.path) {
            self.recordedFileURL = recordedFileURL
            self.duration = min(duration, TimeInterval(maxDuration))
            self.state = .recorded
        }
    }

    // MARK: - Internal Methods

    func startRecording() {
        guard state != .recording, !isPreparingRecording else { return }

        isPreparingRecording = true

        Task {
            let hasPermission = await requestPermission()
            guard isPreparingRecording else { return }

            guard hasPermission else {
                isPreparingRecording = false
                state = .permissionDenied
                return
            }

            do {
                isPreparingRecording = false
                try startRecordingSession()
            } catch {
                isPreparingRecording = false
                state = .failed
            }
        }
    }

    func stopRecording() {
        guard state == .recording else { return }

        audioRecorder?.stop()
        audioRecorder = nil
        stopTimer()

        recordedFileURL = activeFileURL
        activeFileURL = nil
        duration = measuredDuration()
        remainingSeconds = maxDuration
        recordingStartedAt = nil
        state = recordedFileURL == nil ? .idle : .recorded

        deactivateAudioSession()
    }

    func deleteRecording() {
        if state == .recording {
            audioRecorder?.stop()
            audioRecorder = nil
        }

        stopTimer()
        deleteFileIfNeeded(activeFileURL)
        deleteFileIfNeeded(recordedFileURL)
        resetRecording()
        state = .idle

        deactivateAudioSession()
    }

    func cancelRecording() {
        guard state == .recording || isPreparingRecording else { return }
        deleteRecording()
        isPreparingRecording = false
    }

    // MARK: - Private Methods

    private func startRecordingSession() throws {
        deleteRecording()
        try configureAudioSession()

        let fileURL = makeFileURL()
        let recorder = try AVAudioRecorder(url: fileURL, settings: recordingSettings)
        recorder.prepareToRecord()
        recorder.record()

        audioRecorder = recorder
        activeFileURL = fileURL
        recordedFileURL = nil
        duration = 0
        remainingSeconds = maxDuration
        recordingStartedAt = Date()
        state = .recording

        startTimer()
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { isGranted in
                continuation.resume(returning: isGranted)
            }
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .record,
            mode: .default,
            options: [.allowBluetoothHFP]
        )
        try session.setActive(true)
    }

    private var recordingSettings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }

    private func startTimer() {
        stopTimer()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTimerTick()
            }
        }
    }

    private func handleTimerTick() {
        guard state == .recording else {
            stopTimer()
            return
        }

        if remainingSeconds > 1 {
            remainingSeconds -= 1
        } else {
            stopRecording()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func measuredDuration() -> TimeInterval {
        guard let recordingStartedAt else { return 0 }
        return min(Date().timeIntervalSince(recordingStartedAt), TimeInterval(maxDuration))
    }

    private func makeFileURL() -> URL {
        let fileName = UUID().uuidString + ".m4a"
        return fileManager.temporaryDirectory.appendingPathComponent(fileName)
    }

    private func deleteFileIfNeeded(_ fileURL: URL?) {
        guard let fileURL else { return }
        try? fileManager.removeItem(at: fileURL)
    }

    private func resetRecording() {
        activeFileURL = nil
        recordedFileURL = nil
        duration = 0
        remainingSeconds = maxDuration
        recordingStartedAt = nil
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
