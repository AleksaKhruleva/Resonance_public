import Foundation
import Core
import Networking

@MainActor
@Observable
final class CreateAnswerViewModel {

    // MARK: - Internal Types

    enum Intent {
        case finishAudioRecording(fileURL: URL, duration: TimeInterval)
        case deleteAudio
        case submitAnswer
        case dismissToast
    }

    enum State: Equatable {
        case idle
        case publishing
        case published
    }

    enum Limits {
        static let maxAudioDuration = 60
    }

    // MARK: - Properties

    private(set) var state: State = .idle
    private(set) var toast: ToastItem?
    private(set) var question: Question
    private(set) var audioFileURL: URL?
    private(set) var audioDuration: TimeInterval = 0
    private(set) var transcriptionState: CreateViewModel.TranscriptionState = .idle
    private(set) var audioDraftId = UUID()

    private let answerService: AnswerService
    private let transcriptionService: AudioTranscriptionService
    private let onPublished: (() -> Void)?

    var isReadyForPublish: Bool {
        audioFileURL != nil && transcriptionState.textForPublish != nil
    }

    var questionAuthorDisplayName: String {
        question.isAnonymous && !question.isOwnedByCurrentUser ? "Анонимный вопрос" : question.authorNick
    }

    var questionAuthorAvatarData: Data? {
        question.isAnonymous && !question.isOwnedByCurrentUser ? nil : question.authorAvatarData
    }

    // MARK: - Internal Init

    init(
        question: Question,
        answerService: AnswerService = AnswerService(),
        transcriptionService: AudioTranscriptionService = AudioTranscriptionService(),
        onPublished: (() -> Void)?
    ) {
        self.question = question
        self.answerService = answerService
        self.transcriptionService = transcriptionService
        self.onPublished = onPublished
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .finishAudioRecording(let fileURL, let duration):
            finishAudioRecording(fileURL: fileURL, duration: duration)
        case .deleteAudio:
            deleteAudio()
        case .submitAnswer:
            Task { await submitAnswer() }
        case .dismissToast:
            toast = nil
        }
    }

    // MARK: - Private Methods

    private func finishAudioRecording(fileURL: URL, duration: TimeInterval) {
        audioFileURL = fileURL
        audioDuration = duration
        Task { await transcribeAudio(fileURL: fileURL) }
    }

    private func deleteAudio() {
        audioFileURL = nil
        audioDuration = 0
        transcriptionState = .idle
        audioDraftId = UUID()
    }

    private func transcribeAudio(fileURL: URL) async {
        transcriptionState = .transcribing

        do {
            let text = try await transcriptionService.transcribeAudio(fileURL: fileURL)

            guard audioFileURL == fileURL else {
                return
            }

            transcriptionState = .finished(text)
        } catch {
            guard audioFileURL == fileURL else {
                return
            }

            transcriptionState = .failed
        }
    }

    private func submitAnswer() async {
        guard state != .publishing, isReadyForPublish else { return }

        state = .publishing

        let audioData: Data?
        if let audioFileURL {
            do {
                audioData = try Data(contentsOf: audioFileURL)
            } catch {
                state = .idle
                showToast(.answerPublishingFailed)
                return
            }
        } else {
            audioData = nil
        }

        let result = await answerService.createAnswer(
            questionId: question.id,
            isPrivate: false,
            text: answerTextForPublish,
            audioData: audioData,
            duration: audioData == nil ? nil : Int(audioDuration.rounded(.up))
        )

        state = .idle

        switch result {
        case .success:
            state = .published
            onPublished?()
        case .failure:
            showToast(.answerPublishingFailed)
        }
    }

    private var answerTextForPublish: String {
        transcriptionState.textForPublish ?? ""
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }
}
