import Foundation
import Speech

final class AudioTranscriptionService {

    // MARK: - Internal Types

    enum TranscriptionError: LocalizedError {
        case permissionDenied
        case recognizerUnavailable
        case recognitionFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Нет доступа к распознаванию речи"
            case .recognizerUnavailable:
                return "Распознавание речи сейчас недоступно"
            case .recognitionFailed:
                return "Не удалось расшифровать аудио"
            }
        }
    }

    // MARK: - Properties

    private let locale: Locale

    // MARK: - Internal Init

    init(locale: Locale = Locale(identifier: "ru_RU")) {
        self.locale = locale
    }

    // MARK: - Internal Methods

    func transcribeAudio(fileURL: URL) async throws -> String {
        guard await requestAuthorization() else {
            throw TranscriptionError.permissionDenied
        }

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        request.addsPunctuation = true

        return try await withCheckedThrowingContinuation { continuation in
            var didFinish = false

            recognizer.recognitionTask(with: request) { result, error in
                if didFinish {
                    return
                }

                if let result, result.isFinal {
                    didFinish = true
                    let transcription = result.bestTranscription.formattedString
                    continuation.resume(returning: transcription)
                    return
                }

                if error != nil {
                    didFinish = true
                    continuation.resume(throwing: TranscriptionError.recognitionFailed)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    continuation.resume(returning: true)
                case .denied, .restricted, .notDetermined:
                    continuation.resume(returning: false)
                @unknown default:
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
