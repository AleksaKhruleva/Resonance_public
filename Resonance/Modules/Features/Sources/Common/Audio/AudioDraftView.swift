import SwiftUI
import UIComponents

struct AudioDraftView: View {

    private let title: String
    private let maxDuration: Int
    private let onPrepareForRecording: () -> Void
    private let onRecordingCreated: (URL, TimeInterval) -> Void
    private let onRecordingDeleted: () -> Void

    @State private var recorder: AudioRecorder
    @State private var player = AudioPlayer()

    init(
        title: String,
        maxDuration: Int = 60,
        initialRecordingFileURL: URL? = nil,
        initialRecordingDuration: TimeInterval = 0,
        onPrepareForRecording: @escaping () -> Void,
        onRecordingCreated: @escaping (URL, TimeInterval) -> Void,
        onRecordingDeleted: @escaping () -> Void
    ) {
        self.title = title
        self.maxDuration = maxDuration
        self.onPrepareForRecording = onPrepareForRecording
        self.onRecordingCreated = onRecordingCreated
        self.onRecordingDeleted = onRecordingDeleted
        _recorder = State(
            initialValue: AudioRecorder(
                maxDuration: maxDuration,
                recordedFileURL: initialRecordingFileURL,
                duration: initialRecordingDuration
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .fontSize(20, weight: .semibold)

            Text("Максимальная длина записи - \(maxDuration) секунд")
                .foregroundStyle(AppColor.placeholder)

            errorMessage

            switch recorder.state {
            case .idle, .permissionDenied, .failed:
                recordButton
            case .recording:
                recordingControls
            case .recorded:
                playbackControls
            }
        }
        .onChange(of: recorder.recordedFileURL) { _, fileURL in
            handleRecordedFileChange(fileURL)
        }
        .onDisappear {
            recorder.cancelRecording()
            player.stop()
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        switch recorder.state {
        case .idle, .recording, .recorded:
            EmptyView()
        case .permissionDenied:
            Text("Нет доступа к микрофону :(\nВы можете исправить это в Настройках")
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.red)
        case .failed:
            Text("Не удалось записать аудио :(\nПопробуйте позже")
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.red)
        }
    }

    private var recordButton: some View {
        Button {
            onPrepareForRecording()
            player.stop()
            recorder.startRecording()
        } label: {
            Label("Записать аудио", systemImage: "mic.fill")
                .foregroundStyle(AppColor.text)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: audioControlHeight)
        }
        .background(Capsule().fill(AppColor.placeholder.opacity(0.1)))
    }

    private var recordingControls: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(AppColor.red)
                .frame(width: 8, height: 8)

            Text("Осталось: \(formattedTime(recorder.remainingSeconds))")
                .monospacedDigit()
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.text)

            Spacer()

            Button {
                recorder.stopRecording()
            } label: {
                Image(systemName: "stop.fill")
                    .foregroundStyle(AppColor.lightText)
                    .fontSize(16, weight: .bold)
                    .frame(width: audioActionSize, height: audioActionSize)
                    .background(Circle().fill(AppColor.blue))
            }
        }
        .padding(.leading, 24)
        .padding(.trailing, 12)
        .frame(height: audioControlHeight)
        .background(Capsule().fill(AppColor.placeholder.opacity(0.1)))
    }

    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button {
                deleteRecording()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(AppColor.red)
                    .fontSize(18, weight: .semibold)
                    .frame(width: audioActionSize, height: audioActionSize)
                    .background(Circle().fill(AppColor.red.opacity(0.1)))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(formattedTime(Int(player.currentTime.rounded())))
                        .fontSize(AppFontSize.caption, weight: .medium)
                        .monospacedDigit()
                        .foregroundStyle(AppColor.placeholder)

                    Spacer()

                    Text(formattedTime(Int(recorder.duration.rounded())))
                        .fontSize(AppFontSize.caption, weight: .medium)
                        .monospacedDigit()
                        .foregroundStyle(AppColor.placeholder)
                }

                progressCapsule
            }

            Button {
                handlePlayPauseTap()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .foregroundStyle(AppColor.lightText)
                    .fontSize(18, weight: .bold)
                    .frame(width: audioActionSize, height: audioActionSize)
                    .background(Circle().fill(AppColor.blue))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: audioControlHeight)
        .background(Capsule().fill(AppColor.placeholder.opacity(0.1)))
        .animation(.linear(duration: 0.08), value: player.progress)
    }

    private var progressCapsule: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColor.placeholder.opacity(0.16))

                Capsule()
                    .fill(AppColor.text.opacity(0.65))
                    .frame(width: proxy.size.width * player.progress)
            }
        }
        .frame(height: 8)
    }

    private var audioControlHeight: CGFloat {
        64
    }

    private var audioActionSize: CGFloat {
        44
    }

    private func handleRecordedFileChange(_ fileURL: URL?) {
        guard let fileURL else {
            onRecordingDeleted()
            return
        }

        onRecordingCreated(fileURL, recorder.duration)
    }

    private func handlePlayPauseTap() {
        guard let fileURL = recorder.recordedFileURL else { return }

        player.toggle(.url(fileURL))
    }

    private func deleteRecording() {
        player.stop()
        recorder.deleteRecording()
    }

    private func formattedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%01d:%02d", minutes, seconds)
    }
}
