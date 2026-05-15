import SwiftUI
import UIComponents
import Core

struct AudioPlayerSheetView: View {

    private let item: MiniPlayerItem

    private static let seekStep: TimeInterval = 5
    private static let secondaryButtonSize: CGFloat = 44

    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayerStore.self) private var audioPlayerStore

    @State private var sliderProgress: Double = 0
    @State private var isScrubbing = false
    @State private var resumesPlaybackAfterScrubbing = false

    private var displayedItem: MiniPlayerItem {
        audioPlayerStore.currentItem ?? item
    }

    private var displayedCurrentTime: TimeInterval {
        guard isScrubbing else {
            return audioPlayerStore.currentTime
        }

        return audioPlayerStore.duration * sliderProgress
    }

    private var currentSliderProgress: Double {
        isScrubbing ? sliderProgress : audioPlayerStore.progress
    }

    private var itemIconName: String {
        switch displayedItem.subtitle {
        case "Вопрос":
            return "questionmark.message.fill"
        case "Ответ":
            return "ellipsis.message.fill"
        case "Пост":
            return "photo.fill"
        default:
            return "waveform"
        }
    }

    init(item: MiniPlayerItem) {
        self.item = item
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            VStack(spacing: 28) {
                artwork
                metadata
                playbackControls
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSize.horizontalPadding)
            .safeAreaPadding(.top, 28)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            sliderProgress = audioPlayerStore.progress
        }
        .onChange(of: audioPlayerStore.progress) { _, progress in
            guard !isScrubbing else { return }
            sliderProgress = progress
        }
        .onChange(of: audioPlayerStore.isPlaying) { _, isPlaying in
            guard isPlaying, isScrubbing else { return }
            commitScrubbing(resumesPlayback: true)
        }
        .onChange(of: audioPlayerStore.currentItem) { _, currentItem in
            guard currentItem != nil else {
                dismiss()
                return
            }
        }
    }

    private var artwork: some View {
        ZStack {
            Circle()
                .fill(AppColor.blue.opacity(0.12))

            Image(systemName: itemIconName)
                .fontSize(56, weight: .semibold)
                .foregroundStyle(AppColor.blue)
        }
        .frame(width: 140, height: 140)
    }

    private var metadata: some View {
        VStack(spacing: 8) {
            Text(displayedItem.title)
                .fontSize(AppFontSize.title, weight: .semibold)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let subtitle = displayedItem.subtitle {
                Text(subtitle)
                    .foregroundStyle(AppColor.placeholder)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var playbackControls: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { currentSliderProgress },
                        set: { updateSliderProgress($0) }
                    ),
                    in: 0...1,
                    onEditingChanged: handleScrubbingChange
                )
                .tint(AppColor.blue)

                HStack {
                    Text(formattedTime(displayedCurrentTime))
                    Spacer()
                    Text(formattedTime(audioPlayerStore.duration))
                }
                .fontSize(AppFontSize.caption)
                .monospacedDigit()
                .foregroundStyle(AppColor.placeholder)
            }

            HStack(spacing: 28) {
                Button {
                    seek(by: -Self.seekStep)
                } label: {
                    Image(systemName: "gobackward.5")
                        .fontSize(26, weight: .semibold)
                        .frame(width: Self.secondaryButtonSize, height: Self.secondaryButtonSize)
                }
                .buttonStyle(.plain)
                .disabled(audioPlayerStore.duration <= 0)

                Button {
                    handlePlayPauseTap()
                } label: {
                    Image(systemName: audioPlayerStore.isPlaying ? "pause.fill" : "play.fill")
                        .fontSize(28, weight: .bold)
                        .foregroundStyle(AppColor.lightText)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(AppColor.blue))
                }
                .buttonStyle(.plain)

                Button {
                    seek(by: Self.seekStep)
                } label: {
                    Image(systemName: "goforward.5")
                        .fontSize(26, weight: .semibold)
                        .frame(width: Self.secondaryButtonSize, height: Self.secondaryButtonSize)
                }
                .buttonStyle(.plain)
                .disabled(audioPlayerStore.duration <= 0)
            }
        }
    }

    private func handleScrubbingChange(_ isEditing: Bool) {
        if isEditing {
            beginScrubbing()
            return
        }

        commitScrubbing(resumesPlayback: resumesPlaybackAfterScrubbing)
    }

    private func beginScrubbing() {
        guard !isScrubbing else { return }

        resumesPlaybackAfterScrubbing = audioPlayerStore.isPlaying
        sliderProgress = audioPlayerStore.progress
        isScrubbing = true
        audioPlayerStore.pause()
    }

    private func updateSliderProgress(_ progress: Double) {
        if !isScrubbing {
            beginScrubbing()
        }

        sliderProgress = min(max(progress, 0), 1)
    }

    private func commitScrubbing(resumesPlayback: Bool) {
        isScrubbing = false
        audioPlayerStore.seek(
            toProgress: sliderProgress,
            resumesPlayback: resumesPlayback
        )
        sliderProgress = audioPlayerStore.progress
        resumesPlaybackAfterScrubbing = false
    }

    private func handlePlayPauseTap() {
        guard isScrubbing else {
            audioPlayerStore.togglePlayPause()
            sliderProgress = audioPlayerStore.progress
            return
        }

        commitScrubbing(resumesPlayback: true)
    }

    private func seek(by offset: TimeInterval) {
        let baseTime = isScrubbing ? displayedCurrentTime : audioPlayerStore.currentTime
        isScrubbing = false
        audioPlayerStore.seek(toTime: baseTime + offset)
        sliderProgress = audioPlayerStore.progress
        resumesPlaybackAfterScrubbing = false
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        AudioDurationFormatter.string(from: Int(time.rounded()))
    }
}
