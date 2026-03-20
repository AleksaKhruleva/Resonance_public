import AVFoundation
import Foundation
import Observation
import QuartzCore

@MainActor
@Observable
final class AudioPlayer {

    // MARK: - Internal Types

    enum State: Equatable {
        case idle
        case preparing
        case playing
        case paused
        case finished
        case failed
    }

    enum Source: Equatable {
        case url(URL)
        case data(Data)
    }

    // MARK: - Properties

    private(set) var state: State = .idle
    private(set) var currentSource: Source?
    private(set) var duration: TimeInterval = 0
    private(set) var currentTime: TimeInterval = 0
    private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var displayLinkProxy: DisplayLinkProxy?

    var isPlaying: Bool {
        state == .playing
    }

    // MARK: - Internal Methods

    func play(_ source: Source) {
        do {
            state = .preparing
            stopProgressTimer()
            player?.stop()

            try configureAudioSession()

            let player = try makePlayer(for: source)
            player.prepareToPlay()
            player.play()

            self.player = player
            currentSource = source
            duration = player.duration
            currentTime = player.currentTime
            progress = 0
            state = .playing

            startProgressTimer()
        } catch {
            failPlayback()
        }
    }

    func pause() {
        guard state == .playing else { return }

        player?.pause()
        state = .paused
        updateProgress()
        stopProgressTimer()
    }

    func resume() {
        guard state == .paused else { return }
        resumePlayback()
    }

    func toggle(_ source: Source) {
        if currentSource == source {
            switch state {
            case .idle, .preparing, .finished, .failed:
                play(source)
            case .playing, .paused:
                togglePlayPause()
            }
        } else {
            play(source)
        }
    }

    func togglePlayPause() {
        guard player != nil else { return }

        switch state {
        case .playing:
            pause()
        case .paused:
            resumePlayback()
        case .idle, .preparing, .finished, .failed:
            break
        }
    }

    func seek(toProgress progress: Double, resumesPlayback: Bool? = nil) {
        guard duration > 0 else { return }
        seek(
            toTime: duration * min(max(progress, 0), 1),
            resumesPlayback: resumesPlayback
        )
    }

    func seek(toTime time: TimeInterval, resumesPlayback: Bool? = nil) {
        guard let player else { return }

        let shouldResume = resumesPlayback ?? (state == .playing)

        if state == .playing {
            player.pause()
            state = .paused
            stopProgressTimer()
        } else if state == .finished {
            state = .paused
        }

        let maxSeekTime = shouldResume ? max(0, player.duration - 0.05) : player.duration
        let targetTime = min(max(time, 0), maxSeekTime)
        player.currentTime = targetTime
        updateProgress()

        if shouldResume {
            resumePlayback()
        }
    }

    func refreshPlaybackState() {
        updateProgress()
    }

    func stop() {
        player?.stop()
        player = nil
        currentSource = nil
        duration = 0
        currentTime = 0
        progress = 0
        state = .idle
        stopProgressTimer()

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Private Methods

    private func resumePlayback() {
        guard let player else { return }

        do {
            try configureAudioSession()
            if player.duration > 0, player.currentTime >= player.duration {
                player.currentTime = 0
                currentTime = 0
                progress = 0
            }
            player.play()
            state = .playing
            startProgressTimer()
        } catch {
            failPlayback()
        }
    }

    private func makePlayer(for source: Source) throws -> AVAudioPlayer {
        switch source {
        case .url(let url):
            return try AVAudioPlayer(contentsOf: url)
        case .data(let data):
            return try AVAudioPlayer(data: data)
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()

        let proxy = DisplayLinkProxy { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
        let displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick))
        displayLink.add(to: .main, forMode: .common)

        displayLinkProxy = proxy
        self.displayLink = displayLink
    }

    private func updateProgress() {
        guard let player else { return }

        duration = player.duration
        currentTime = player.currentTime

        if state == .playing, !player.isPlaying {
            handlePlaybackFinished()
            return
        }

        if duration > 0 {
            progress = min(max(currentTime / duration, 0), 1)
        }
    }

    private func stopProgressTimer() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
    }

    private func failPlayback() {
        player = nil
        duration = 0
        currentTime = 0
        progress = 0
        state = .failed
        stopProgressTimer()

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func handlePlaybackFinished() {
        player?.stop()
        player?.currentTime = 0
        currentTime = 0
        progress = 0
        state = .finished
        stopProgressTimer()

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .playback,
            mode: .spokenAudio
        )
        try session.setActive(true)
    }
}

private final class DisplayLinkProxy: NSObject {

    private let onTick: () -> Void

    init(onTick: @escaping () -> Void) {
        self.onTick = onTick
    }

    @objc func tick() {
        onTick()
    }
}
