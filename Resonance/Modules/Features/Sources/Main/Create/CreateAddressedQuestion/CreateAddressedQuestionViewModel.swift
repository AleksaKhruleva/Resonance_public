import SwiftUI
import Networking
import Core

@MainActor
@Observable
final class CreateAddressedQuestionViewModel {

    enum Intent {
        case selectQuestionFormat(CreateViewModel.QuestionContentFormat)
        case selectQuestionAuthorAnonymity(CreateViewModel.QuestionAuthorAnonymity)
        case updateQuestionText(String)
        case finishQuestionAudioRecording(fileURL: URL, duration: TimeInterval)
        case deleteQuestionAudio
        case submitQuestion
        case dismissToast
    }

    enum State {
        case idle
        case publishing
        case published
    }

    private(set) var state: State = .idle
    private(set) var toast: ToastItem?
    private(set) var questionAuthorAnonymity: CreateViewModel.QuestionAuthorAnonymity = .identified
    private(set) var questionContentFormat: CreateViewModel.QuestionContentFormat = .audio
    private(set) var questionText = ""
    private(set) var questionAudioFileURL: URL?
    private(set) var questionAudioDuration: TimeInterval = 0
    private(set) var questionTranscriptionState: CreateViewModel.TranscriptionState = .idle
    private(set) var questionAudioDraftId = UUID()

    private let recipient: UserProfile
    private let createService: CreateService
    private let transcriptionService: AudioTranscriptionService
    private let onQuestionPublished: (() -> Void)?

    var isQuestionReadyForPublish: Bool {
        switch questionContentFormat {
        case .text:
            return !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .audio:
            return questionAudioFileURL != nil && questionTranscriptionState.textForPublish != nil
        }
    }

    init(
        recipient: UserProfile,
        createService: CreateService = CreateService(),
        transcriptionService: AudioTranscriptionService = AudioTranscriptionService(),
        onQuestionPublished: (() -> Void)?
    ) {
        self.recipient = recipient
        self.createService = createService
        self.transcriptionService = transcriptionService
        self.onQuestionPublished = onQuestionPublished
    }

    func handle(_ intent: Intent) {
        switch intent {
        case .selectQuestionFormat(let format):
            selectQuestionFormat(format)
        case .selectQuestionAuthorAnonymity(let anonymity):
            questionAuthorAnonymity = anonymity
        case .updateQuestionText(let text):
            updateQuestionText(text)
        case .finishQuestionAudioRecording(let fileURL, let duration):
            finishQuestionAudioRecording(fileURL: fileURL, duration: duration)
        case .deleteQuestionAudio:
            deleteQuestionAudio()
        case .submitQuestion:
            Task { await submitQuestion() }
        case .dismissToast:
            toast = nil
        }
    }

    private func selectQuestionFormat(_ format: CreateViewModel.QuestionContentFormat) {
        questionContentFormat = format
    }

    private func updateQuestionText(_ text: String) {
        questionText = String(text.prefix(CreateViewModel.Limits.maxQuestionTextLength))
    }

    private func finishQuestionAudioRecording(fileURL: URL, duration: TimeInterval) {
        questionAudioFileURL = fileURL
        questionAudioDuration = duration
        Task { await transcribeQuestionAudio(fileURL: fileURL) }
    }

    private func deleteQuestionAudio() {
        removeAudioFileIfNeeded(at: questionAudioFileURL)
        questionAudioFileURL = nil
        questionAudioDuration = 0
        questionTranscriptionState = .idle
        questionAudioDraftId = UUID()
    }

    private func transcribeQuestionAudio(fileURL: URL) async {
        questionTranscriptionState = .transcribing

        do {
            let text = try await transcriptionService.transcribeAudio(fileURL: fileURL)

            guard questionAudioFileURL == fileURL else {
                return
            }

            questionTranscriptionState = .finished(text)
        } catch {
            guard questionAudioFileURL == fileURL else {
                return
            }

            questionTranscriptionState = .failed
        }
    }

    private func submitQuestion() async {
        guard state != .publishing, isQuestionReadyForPublish else { return }

        state = .publishing

        let audioData: Data?
        if questionContentFormat == .audio, let questionAudioFileURL {
            do {
                audioData = try Data(contentsOf: questionAudioFileURL)
            } catch {
                state = .idle
                showToast(.questionPublishingFailed)
                return
            }
        } else {
            audioData = nil
        }

        let result = await createService.createQuestion(
            recipientId: recipient.id,
            isAnonymous: questionAuthorAnonymity.isAnonymous,
            text: questionTextForPublish,
            audioData: audioData,
            duration: audioData == nil ? nil : Int(questionAudioDuration.rounded(.up))
        )

        state = .idle

        switch result {
        case .success:
            resetQuestionDraft()
            state = .published
            onQuestionPublished?()
        case .failure:
            showToast(.questionPublishingFailed)
        }
    }

    private var questionTextForPublish: String {
        switch questionContentFormat {
        case .text:
            return questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .audio:
            return questionTranscriptionState.textForPublish ?? ""
        }
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }

    private func resetQuestionDraft() {
        removeAudioFileIfNeeded(at: questionAudioFileURL)
        questionAuthorAnonymity = .identified
        questionContentFormat = .audio
        questionText = ""
        questionAudioFileURL = nil
        questionAudioDuration = 0
        questionTranscriptionState = .idle
        questionAudioDraftId = UUID()
    }

    private func removeAudioFileIfNeeded(at fileURL: URL?) {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
