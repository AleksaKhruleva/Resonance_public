import SwiftUI
import Networking
import Core

@MainActor
@Observable
final class CreateViewModel {

    // MARK: - Internal Types

    enum Intent {
        case selectContent(ContentType)
        case setPostImageData(Data)
        case deletePostImage
        case startAudioRecording
        case finishAudioRecording(fileURL: URL, duration: TimeInterval)
        case deleteAudio
        case toggleAudioPlayback
        case updateAudioPlaybackProgress(Double)
        case finishAudioPlayback
        case submitPost
        case dismissToast
        case selectQuestionFormat(QuestionContentFormat)
        case selectQuestionAuthorAnonymity(QuestionAuthorAnonymity)
        case updateQuestionText(String)
        case finishQuestionAudioRecording(fileURL: URL, duration: TimeInterval)
        case deleteQuestionAudio
        case submitQuestion
    }

    enum State {
        case idle
        case publishing
    }

    enum ContentType: String, CaseIterable, Identifiable {
        case post = "Пост"
        case question = "Вопрос"

        var id: Self { self }
    }

    enum QuestionContentFormat: String, CaseIterable, Identifiable {
        case audio = "Аудио"
        case text = "Текст"

        var id: Self { self }
        var isAudio: Bool { self == .audio }
        var isText: Bool { self == .text }
    }

    enum QuestionAuthorAnonymity: String, CaseIterable, Identifiable {
        case identified = "Публично"
        case anonymous = "Анонимно"

        var id: Self { self }
        var isIdentified: Bool { self == .identified }
        var isAnonymous: Bool { self == .anonymous }

        var explanation: String {
            switch self {
            case .identified:
                return "Ваш профиль будет виден получателю"
            case .anonymous:
                return "Ваш профиль не будет виден получателю"
            }
        }
    }

    enum TranscriptionState: Equatable {
        case idle
        case transcribing
        case finished(String)
        case failed

        var textForPublish: String? {
            guard case .finished(let text) = self else { return nil }

            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedText.isEmpty ? nil : trimmedText
        }
    }

    enum Limits {
        static let maxQuestionTextLength = 1000
        static let maxAudioDuration = 60
    }

    struct CropperPayload: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    // MARK: - Properties

    private(set) var state: State = .idle
    private(set) var toast: ToastItem?
    private(set) var selectedContentType: ContentType = .post
    private(set) var postImageData: Data?
    private(set) var audioFileURL: URL?
    private(set) var audioDuration: TimeInterval = 0
    private(set) var audioPlaybackProgress: Double = 0
    private(set) var isAudioRecording = false
    private(set) var isAudioPlaying = false
    private(set) var postAudioDraftId = UUID()
    private(set) var questionAuthorAnonymity: QuestionAuthorAnonymity = .identified
    private(set) var questionContentFormat: QuestionContentFormat = .audio
    private(set) var questionText = ""
    private(set) var questionAudioFileURL: URL?
    private(set) var questionAudioDuration: TimeInterval = 0
    private(set) var questionTranscriptionState: TranscriptionState = .idle
    private(set) var questionAudioDraftId = UUID()

    private let createService: CreateService
    private let transcriptionService: AudioTranscriptionService
    private let onPostPublished: (() -> Void)?
    private let onQuestionPublished: (() -> Void)?

    var isPostReadyForPublish: Bool {
        postImageData != nil && audioFileURL != nil
    }

    var isQuestionReadyForPublish: Bool {
        switch questionContentFormat {
        case .text:
            return !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .audio:
            return questionAudioFileURL != nil && questionTranscriptionState.textForPublish != nil
        }
    }

    // MARK: - Internal Init

    init(
        createService: CreateService = CreateService(),
        transcriptionService: AudioTranscriptionService = AudioTranscriptionService(),
        onPostPublished: (() -> Void)? = nil,
        onQuestionPublished: (() -> Void)? = nil
    ) {
        self.createService = createService
        self.transcriptionService = transcriptionService
        self.onPostPublished = onPostPublished
        self.onQuestionPublished = onQuestionPublished
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .selectContent(let content):
            selectedContentType = content
        case .setPostImageData(let imageData):
            postImageData = imageData
        case .deletePostImage:
            postImageData = nil
        case .startAudioRecording:
            startAudioRecording()
        case .finishAudioRecording(let fileURL, let duration):
            finishAudioRecording(fileURL: fileURL, duration: duration)
        case .deleteAudio:
            deleteAudio()
        case .toggleAudioPlayback:
            toggleAudioPlayback()
        case .updateAudioPlaybackProgress(let progress):
            audioPlaybackProgress = min(max(progress, 0), 1)
        case .finishAudioPlayback:
            finishAudioPlayback()
        case .submitPost:
            Task { await submitPost() }
        case .dismissToast:
            toast = nil
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
        }
    }

    // MARK: - Private Methods

    private func startAudioRecording() {
        isAudioRecording = true
        isAudioPlaying = false
        audioPlaybackProgress = 0
    }

    private func finishAudioRecording(fileURL: URL, duration: TimeInterval) {
        isAudioRecording = false
        audioFileURL = fileURL
        audioDuration = duration
        audioPlaybackProgress = 0
    }

    private func deleteAudio() {
        removeAudioFileIfNeeded(at: audioFileURL)
        audioFileURL = nil
        audioDuration = 0
        audioPlaybackProgress = 0
        isAudioRecording = false
        isAudioPlaying = false
        postAudioDraftId = UUID()
    }

    private func toggleAudioPlayback() {
        guard audioFileURL != nil else { return }
        isAudioPlaying.toggle()
    }

    private func finishAudioPlayback() {
        isAudioPlaying = false
        audioPlaybackProgress = 0
    }

    private func submitPost() async {
        guard
            state != .publishing,
            let imageData = postImageData,
            let audioFileURL
        else {
            return
        }

        state = .publishing

        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioFileURL)
        } catch {
            state = .idle
            showToast(.postPublishingFailed)
            return
        }

        let result = await createService.createPost(
            imageData: imageData,
            audioData: audioData,
            duration: Int(audioDuration.rounded(.up))
        )

        state = .idle

        switch result {
        case .success:
            resetPostDraft()
            onPostPublished?()
        case .failure:
            showToast(.postPublishingFailed)
        }
    }

    private func resetPostDraft() {
        removeAudioFileIfNeeded(at: audioFileURL)
        postImageData = nil
        audioFileURL = nil
        audioDuration = 0
        audioPlaybackProgress = 0
        isAudioRecording = false
        isAudioPlaying = false
        postAudioDraftId = UUID()
    }

    private func selectQuestionFormat(_ format: QuestionContentFormat) {
        questionContentFormat = format
    }

    private func updateQuestionText(_ text: String) {
        questionText = String(text.prefix(Self.Limits.maxQuestionTextLength))
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
            recipientId: 0,
            isAnonymous: questionAuthorAnonymity.isAnonymous,
            text: questionTextForPublish,
            audioData: audioData,
            duration: audioData == nil ? nil : Int(questionAudioDuration.rounded(.up))
        )

        state = .idle

        switch result {
        case .success:
            resetQuestionDraft()
            onQuestionPublished?()
        case .failure:
            showToast(.questionPublishingFailed)
        }
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }

    private var questionTextForPublish: String {
        switch questionContentFormat {
        case .text:
            return questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .audio:
            return questionTranscriptionState.textForPublish ?? ""
        }
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
