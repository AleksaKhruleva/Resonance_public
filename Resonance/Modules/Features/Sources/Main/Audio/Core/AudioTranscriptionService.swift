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

    // MARK: - Private Types

    private struct Word {
        let text: String
        let lowercased: String
        let pauseAfter: TimeInterval?
    }

    private struct PauseLimits {
        let question: TimeInterval
        let comma: TimeInterval
        let sentence: TimeInterval
        let strongSentence: TimeInterval
    }

    private enum Limits {
        static let defaultAveragePause: TimeInterval = 0.35
        static let minSentenceWords = 2
        static let minCommaWords = 4
        static let longPhraseWords = 6
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

        guard let recognizer = makeRecognizer() else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = makeRequest(fileURL: fileURL)
        return try await transcribeAudio(with: recognizer, request: request)
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

    private func makeRecognizer() -> SFSpeechRecognizer? {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            return nil
        }

        return recognizer
    }

    private func makeRequest(fileURL: URL) -> SFSpeechURLRecognitionRequest {
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = false
        return request
    }

    private func transcribeAudio(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechURLRecognitionRequest
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var didFinish = false

            let task = recognizer.recognitionTask(with: request) { result, error in
                guard !didFinish else { return }

                if let result, result.isFinal {
                    didFinish = true
                    continuation.resume(
                        returning: Self.makeReadableText(
                            from: result.bestTranscription,
                            averagePause: result.speechRecognitionMetadata?.averagePauseDuration
                        )
                    )
                    return
                }

                if error != nil {
                    didFinish = true
                    continuation.resume(throwing: TranscriptionError.recognitionFailed)
                }
            }

            _ = task
        }
    }

    private static func makeReadableText(
        from transcription: SFTranscription,
        averagePause: TimeInterval?
    ) -> String {
        guard !transcription.segments.isEmpty else {
            return makeFallbackText(from: transcription.formattedString)
        }

        let words = makeWords(from: transcription)
        guard !words.isEmpty else { return makeFallbackText(from: transcription.formattedString) }

        let pauseLimits = makePauseLimits(averagePause: averagePause)
        var result = ""
        var sentenceStart = 0

        for index in words.indices {
            if !result.isEmpty { result.append(" ") }

            let word = readableWord(
                words[index].text,
                startsSentence: index == sentenceStart
            )
            let punctuation = punctuationAfterWord(
                at: index,
                sentenceStart: sentenceStart,
                words: words,
                pauseLimits: pauseLimits
            )

            result.append(word)
            result.append(punctuation)

            if punctuation == "." || punctuation == "?" {
                sentenceStart = index + 1
            }
        }

        return result
    }

    private static func makeWords(from transcription: SFTranscription) -> [Word] {
        transcription.segments.enumerated().flatMap { index, segment -> [Word] in
            let tokens = wordTokens(in: segment.substring)
            guard !tokens.isEmpty else { return [] }

            let pause = pauseAfterSegment(
                at: index,
                segment: segment,
                transcription: transcription
            )

            return tokens.enumerated().map { tokenIndex, token in
                Word(
                    text: token,
                    lowercased: normalize(token),
                    pauseAfter: tokenIndex == tokens.count - 1 ? pause : nil
                )
            }
        }
    }

    private static func readableWord(_ word: String, startsSentence: Bool) -> String {
        startsSentence ? capitalizedFirstLetter(word) : word
    }

    private static func pauseAfterSegment(
        at index: Int,
        segment: SFTranscriptionSegment,
        transcription: SFTranscription
    ) -> TimeInterval? {
        guard transcription.segments.indices.contains(index + 1) else { return nil }

        let nextSegment = transcription.segments[index + 1]
        return max(0, nextSegment.timestamp - (segment.timestamp + segment.duration))
    }

    private static func punctuationAfterWord(
        at index: Int,
        sentenceStart: Int,
        words: [Word],
        pauseLimits: PauseLimits
    ) -> String {
        if index == words.count - 1 {
            return sentenceEnding(for: words[sentenceStart...index])
        }

        let pause = words[index].pauseAfter ?? 0
        let sentenceLength = index - sentenceStart + 1
        let nextWord = words[index + 1].lowercased

        if shouldEndSentence(
            afterPause: pause,
            sentenceLength: sentenceLength,
            nextWord: nextWord,
            words: words[sentenceStart...index],
            pauseLimits: pauseLimits
        ) {
            return sentenceEnding(for: words[sentenceStart...index])
        }

        if shouldAddCommaBeforeConjunction(after: index, sentenceStart: sentenceStart, words: words) {
            return ","
        }

        return shouldAddComma(
            afterPause: pause,
            sentenceLength: sentenceLength,
            nextWord: nextWord,
            pauseLimits: pauseLimits
        ) ? "," : ""
    }

    private static func shouldEndSentence(
        afterPause pause: TimeInterval,
        sentenceLength: Int,
        nextWord: String,
        words: ArraySlice<Word>,
        pauseLimits: PauseLimits
    ) -> Bool {
        guard sentenceLength >= Limits.minSentenceWords else {
            return false
        }

        if isContinuationWord(nextWord), pause < pauseLimits.strongSentence {
            return false
        }

        if pause >= pauseLimits.strongSentence {
            return true
        }

        if pause >= pauseLimits.sentence {
            return startsNewSentence(nextWord) || sentenceLength >= Limits.longPhraseWords
        }

        return pause >= pauseLimits.question && isQuestion(words) && startsNewSentence(nextWord)
    }

    private static func shouldAddComma(
        afterPause pause: TimeInterval,
        sentenceLength: Int,
        nextWord: String,
        pauseLimits: PauseLimits
    ) -> Bool {
        pause >= pauseLimits.comma
        && sentenceLength >= Limits.minCommaWords
        && !isWeakWord(nextWord)
        && !startsNewSentence(nextWord)
    }

    private static func shouldAddCommaBeforeConjunction(
        after index: Int,
        sentenceStart: Int,
        words: [Word]
    ) -> Bool {
        let nextIndex = index + 1
        guard nextIndex < words.count else { return false }

        let word = words[index].lowercased
        let nextWord = words[nextIndex].lowercased

        if word == "потому", nextWord == "что" { return false }
        if word == "так", nextWord == "как" { return false }
        if nextWord == "как", questionRequestWords.contains(words[sentenceStart].lowercased) { return true }
        if commaConjunctions.contains(nextWord) { return true }

        return phraseStarts(at: nextIndex, words: words, phrase: ["потому", "что"])
        || phraseStarts(at: nextIndex, words: words, phrase: ["так", "как"])
    }

    private static func sentenceEnding(for words: ArraySlice<Word>) -> String {
        isQuestion(words) ? "?" : "."
    }

    private static func isQuestion(_ words: ArraySlice<Word>) -> Bool {
        let items = words.map(\.lowercased)
        guard let first = items.first else { return false }

        return questionWords.contains(first)
        || questionStarters.contains(first)
        || questionRequestWords.contains(first) && items.contains(where: questionWords.contains)
        || items.prefix(7).contains("ли")
    }

    private static func startsNewSentence(_ word: String) -> Bool {
        sentenceStarterWords.contains(word)
    }

    private static func isContinuationWord(_ word: String) -> Bool {
        continuationWords.contains(word)
    }

    private static func isWeakWord(_ word: String) -> Bool {
        continuationWords.contains(word) || prepositions.contains(word)
    }

    private static func phraseStarts(at index: Int, words: [Word], phrase: [String]) -> Bool {
        guard index + phrase.count <= words.count else { return false }
        return phrase.enumerated().allSatisfy { words[index + $0.offset].lowercased == $0.element }
    }

    private static func makePauseLimits(averagePause: TimeInterval?) -> PauseLimits {
        let pause = averagePause ?? Limits.defaultAveragePause

        return PauseLimits(
            question: limited(pause * 1.1, min: 0.32, max: 0.4),
            comma: limited(pause * 1.15, min: 0.34, max: 0.45),
            sentence: limited(pause * 1.2, min: 0.38, max: 0.5),
            strongSentence: limited(pause * 2.2, min: 0.7, max: 0.9)
        )
    }

    private static func limited(_ value: TimeInterval, min: TimeInterval, max: TimeInterval) -> TimeInterval {
        Swift.min(Swift.max(value, min), max)
    }

    private static func wordTokens(in text: String) -> [String] {
        let pattern = "[\\p{L}\\p{M}\\d]+(?:[-‑][\\p{L}\\p{M}\\d]+)*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    private static func makeFallbackText(from text: String) -> String {
        var result = replace(pattern: "\\s+", in: text.trimmingCharacters(in: .whitespacesAndNewlines), with: " ")
        result = replace(pattern: "\\s+([,.!?])", in: result, with: "$1")
        result = replace(pattern: "([,.!?])([^\\s])", in: result, with: "$1 $2")
        result = capitalizedFirstLetter(result)

        if let last = result.last, !".!?".contains(last) {
            result.append(".")
        }

        return result
    }

    private static func capitalizedFirstLetter(_ text: String) -> String {
        guard let firstIndex = text.firstIndex(where: { $0.isLetter }) else { return text }

        var result = text
        let nextIndex = result.index(after: firstIndex)
        result.replaceSubrange(firstIndex..<nextIndex, with: String(result[firstIndex]).uppercased())
        return result
    }

    private static func normalize(_ word: String) -> String {
        word.lowercased(with: Locale(identifier: "ru_RU"))
    }

    private static func replace(pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }

    private static let continuationWords: Set<String> = [
        "и", "или", "либо", "а", "но", "да", "же", "бы", "ли", "не", "ни",
        "что", "чтобы", "если", "когда", "пока", "хотя", "потому", "так"
    ]
    private static let prepositions: Set<String> = [
        "в", "во", "на", "по", "за", "из", "от", "до", "для", "с", "со", "к", "ко", "у", "о", "об",
        "про", "при", "через", "над", "под", "без"
    ]
    private static let commaConjunctions: Set<String> = ["а", "но", "что", "чтобы", "если", "хотя"]
    private static let questionWords: Set<String> = [
        "кто", "что", "где", "куда", "откуда", "когда", "почему", "зачем", "как",
        "какой", "какая", "какое", "какие", "сколько", "насколько",
        "чей", "чья", "чье", "чьи"
    ]
    private static let questionStarters: Set<String> = [
        "можно", "можешь", "можете", "могу", "сможешь", "сможете",
        "будешь", "будете", "хочешь", "хотите", "разве", "неужели"
    ]
    private static let questionRequestWords: Set<String> = [
        "скажи", "скажите", "расскажи", "расскажите", "подскажи", "подскажите"
    ]
    private static let sentenceStarterWords: Set<String> = [
        "я", "мы", "ты", "вы", "он", "она", "они",
        "это", "этот", "эта", "эти",
        "кто", "почему", "зачем", "как", "сколько",
        "там", "тут", "здесь", "сейчас", "потом", "затем", "поэтому", "значит", "дальше"
    ]
}
