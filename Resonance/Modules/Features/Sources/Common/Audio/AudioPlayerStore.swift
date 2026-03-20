import Foundation
import SwiftUI
import Core
import QuartzCore

struct MiniPlayerItem: Equatable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let audio: Audio

    static func == (lhs: MiniPlayerItem, rhs: MiniPlayerItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
@Observable
final class AudioPlayerStore {
    
    var currentItem: MiniPlayerItem?
    var isPlaying = false
    var progress: Double = 0
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    
    private let player = AudioPlayer()
    private var displayLink: CADisplayLink?
    private var displayLinkProxy: StoreDisplayLinkProxy?
    
    func play(_ item: MiniPlayerItem) {
        player.play(.data(item.audio.data))
        guard player.state != .failed else {
            stop()
            return
        }

        currentItem = item
        duration = TimeInterval(item.audio.durationSeconds)
        currentTime = 0
        progress = 0
        syncPlaybackState()
        updateProgressTimer()
    }
    
    func togglePlayPause() {
        guard let currentItem else { return }

        switch player.state {
        case .playing, .paused:
            player.togglePlayPause()
        case .finished, .idle, .failed:
            player.play(.data(currentItem.audio.data))
        case .preparing:
            break
        }

        syncPlaybackState()
        updateProgressTimer()
    }

    func pause() {
        player.pause()
        syncPlaybackState()
        updateProgressTimer()
    }

    func seek(toProgress progress: Double, resumesPlayback: Bool? = nil) {
        player.seek(toProgress: progress, resumesPlayback: resumesPlayback)
        syncPlaybackState()
        updateProgressTimer()
    }

    func seek(toTime time: TimeInterval, resumesPlayback: Bool? = nil) {
        player.seek(toTime: time, resumesPlayback: resumesPlayback)
        syncPlaybackState()
        updateProgressTimer()
    }
    
    func stop() {
        player.stop()
        currentItem = nil
        isPlaying = false
        progress = 0
        currentTime = 0
        duration = 0
        stopProgressTimer()
    }
    
    func isPlaying(_ item: MiniPlayerItem) -> Bool {
        currentItem?.id == item.id && isPlaying
    }

    func isCurrentItem(_ item: MiniPlayerItem) -> Bool {
        currentItem?.id == item.id
    }
    
    func handleTap(on item: MiniPlayerItem) {
        if currentItem?.id == item.id {
            togglePlayPause()
        } else {
            play(item)
        }
    }

    func restartCurrentItem() {
        guard let currentItem else { return }
        play(currentItem)
    }
    
    private func startProgressTimer() {
        stopProgressTimer()

        let proxy = StoreDisplayLinkProxy { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
        let displayLink = CADisplayLink(target: proxy, selector: #selector(StoreDisplayLinkProxy.tick))
        displayLink.preferredFramesPerSecond = 15
        displayLink.add(to: .main, forMode: .common)

        displayLinkProxy = proxy
        self.displayLink = displayLink
    }
    
    private func updateProgress() {
        player.refreshPlaybackState()
        syncPlaybackState()

        if player.state == .idle || player.state == .finished || player.state == .failed {
            stopProgressTimer()
        }
    }
    
    private func stopProgressTimer() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkProxy = nil
    }

    private func updateProgressTimer() {
        if player.isPlaying || player.state == .preparing {
            startProgressTimer()
        } else {
            stopProgressTimer()
        }
    }

    private func syncPlaybackState() {
        let newIsPlaying = player.isPlaying
        if isPlaying != newIsPlaying {
            isPlaying = newIsPlaying
        }

        let newDuration = player.duration > 0 ? player.duration : duration
        if duration != newDuration {
            duration = newDuration
        }

        if player.state == .finished {
            if currentTime != duration {
                currentTime = duration
            }

            let finishedProgress = duration > 0 ? 1.0 : 0.0
            if progress != finishedProgress {
                progress = finishedProgress
            }
        } else {
            if currentTime != player.currentTime {
                currentTime = player.currentTime
            }

            if progress != player.progress {
                progress = player.progress
            }
        }
    }
}

private final class StoreDisplayLinkProxy: NSObject {

    private let onTick: () -> Void

    init(onTick: @escaping () -> Void) {
        self.onTick = onTick
    }

    @objc func tick() {
        onTick()
    }
}
