import SwiftUI
import Core
import Networking

@MainActor
@Observable
final class QuestionDetailedViewModel {

    enum Intent {
        case loadQuestion
        case refreshQuestion
        case loadNextBatchIfNeeded(answerId: Int)
        case openUserProfile(userNick: String)
        case answerPublished(questionId: Int)
        case toggleAnswerLike(answerId: Int)
        case answerLikeChanged(answerId: Int, isLiked: Bool, likesCount: Int)
        case requestAnswerDeletion(answerId: Int)
        case dismissAnswerDeletion
        case cancelAnswerDeletion
        case confirmAnswerDeletion
        case answerDeleted(answerId: Int)
        case toggleBestAnswer(answerId: Int)
        case bestAnswerChanged(questionId: Int, answerId: Int, isBest: Bool)
        case requestQuestionDeletion
        case cancelQuestionDeletion
        case confirmQuestionDeletion
        case dismissToast
    }

    enum State: Equatable {
        case idle
        case loadingQuestion
        case loadingNextBatch
        case refreshingQuestion
        case content
        case deleting
        case error(String?)
    }

    private(set) var state: State = .idle
    private(set) var toast: ToastItem?
    private(set) var question: Question?
    private(set) var isDeleteConfirmationPresented = false
    private(set) var answerPendingDeletion: Answer?
    private(set) var isAnswerDeleteConfirmationPresented = false
    private(set) var shouldDismiss = false

    private var hasMoreAnswers = true
    private var latestAnswerId: Int?
    private var lastQuestionLoadedAt: Date?
    private var likingAnswerIds = Set<Int>()
    private var deletingAnswerIds = Set<Int>()
    private var updatingBestAnswerIds = Set<Int>()

    private let questionId: Int
    private let questionService: QuestionService
    private let answerService: AnswerService
    private let onAuthorTap: ((String) -> Void)?

    private static let batchSize = 10
    private static let questionRefreshInterval: TimeInterval = 2 * 60

    private var isLoading: Bool {
        state == .loadingQuestion || state == .refreshingQuestion || state == .loadingNextBatch || state == .deleting
    }

    private var isRefreshing: Bool {
        lastQuestionLoadedAt != nil
    }

    private var shouldUpdateData: Bool {
        guard let lastQuestionLoadedAt else { return true }
        return Date().timeIntervalSince(lastQuestionLoadedAt) > Self.questionRefreshInterval
    }

    init(
        questionId: Int,
        questionService: QuestionService = QuestionService(),
        answerService: AnswerService = AnswerService(),
        onAuthorTap: ((String) -> Void)?
    ) {
        self.questionId = questionId
        self.questionService = questionService
        self.answerService = answerService
        self.onAuthorTap = onAuthorTap
    }

    func handle(_ intent: Intent) {
        switch intent {
        case .loadQuestion:
            Task { await loadQuestion() }
        case .refreshQuestion:
            Task { await loadQuestion(forcedUpdate: true) }
        case .loadNextBatchIfNeeded(let answerId):
            guard answerId == latestAnswerId else { return }
            Task { await loadNextBatch() }
        case .openUserProfile(let authorNick):
            onAuthorTap?(authorNick)
        case .answerPublished(let questionId):
            Task { await refreshAnsweredQuestion(questionId: questionId) }
        case .toggleAnswerLike(let answerId):
            Task { await toggleAnswerLike(answerId: answerId) }
        case .answerLikeChanged(let answerId, let isLiked, let likesCount):
            applyAnswerLikeChanged(answerId: answerId, isLiked: isLiked, likesCount: likesCount)
        case .requestAnswerDeletion(let answerId):
            requestAnswerDeletion(answerId: answerId)
        case .dismissAnswerDeletion:
            isAnswerDeleteConfirmationPresented = false
        case .cancelAnswerDeletion:
            isAnswerDeleteConfirmationPresented = false
            answerPendingDeletion = nil
        case .confirmAnswerDeletion:
            Task { await confirmAnswerDeletion() }
        case .answerDeleted(let answerId):
            removeAnswer(answerId: answerId)
        case .toggleBestAnswer(let answerId):
            Task { await toggleBestAnswer(answerId: answerId) }
        case .bestAnswerChanged(let questionId, let answerId, let isBest):
            guard questionId == self.questionId else { return }
            applyBestAnswer(answerId: answerId, isBest: isBest)
        case .requestQuestionDeletion:
            guard question?.isOwnedByCurrentUser == true else { return }
            isDeleteConfirmationPresented = true
        case .cancelQuestionDeletion:
            isDeleteConfirmationPresented = false
        case .confirmQuestionDeletion:
            Task { await confirmQuestionDeletion() }
        case .dismissToast:
            toast = nil
        }
    }

    func isAnswerLikeLoading(answerId: Int) -> Bool {
        likingAnswerIds.contains(answerId)
    }

    func isAnswerDeleting(answerId: Int) -> Bool {
        deletingAnswerIds.contains(answerId)
    }

    func isBestAnswerUpdating(answerId: Int) -> Bool {
        updatingBestAnswerIds.contains(answerId)
    }

    private func loadQuestion(forcedUpdate: Bool = false) async {
        guard !isLoading, shouldUpdateData || forcedUpdate else { return }

        state = isRefreshing ? .refreshingQuestion : .loadingQuestion

        let result = await questionService.getQuestionDetails(
            questionId: questionId,
            batchSize: Self.batchSize
        )

        switch result {
        case .success(let loadedQuestion):
            question = loadedQuestion
            latestAnswerId = loadedQuestion.answers.last?.id
            hasMoreAnswers = loadedQuestion.answers.count < loadedQuestion.answersCount
            lastQuestionLoadedAt = Date()
            state = .content
        case .failure(let error):
            if isRefreshing, question != nil {
                state = .content
                showToast(.refreshFailed)
            } else {
                state = .error(error.localizedDescription)
            }
        }
    }

    private func loadNextBatch() async {
        guard
            state == .content,
            hasMoreAnswers,
            let latestAnswerId
        else {
            return
        }

        state = .loadingNextBatch

        let result = await questionService.getQuestionDetailsNextAnswers(
            questionId: questionId,
            batchSize: Self.batchSize,
            answerId: latestAnswerId
        )

        switch result {
        case .success(let loadedAnswers):
            appendAnswers(loadedAnswers)
            self.latestAnswerId = loadedAnswers.last?.id ?? latestAnswerId
            if let question {
                hasMoreAnswers = question.answers.count < question.answersCount && !loadedAnswers.isEmpty
            } else {
                hasMoreAnswers = false
            }
            lastQuestionLoadedAt = Date()
            state = .content
        case .failure:
            state = .content
            showToast(.nextBatchLoadFailed)
        }
    }

    private func appendAnswers(_ answers: [Answer]) {
        guard !answers.isEmpty, var updatedQuestion = question else { return }

        var existingAnswerIds = Set(updatedQuestion.answers.map(\.id))
        let newAnswers = answers.filter { existingAnswerIds.insert($0.id).inserted }
        updatedQuestion.answers.append(contentsOf: newAnswers)
        question = updatedQuestion
    }

    private func toggleAnswerLike(answerId: Int) async {
        guard
            !likingAnswerIds.contains(answerId),
            var updatedQuestion = question,
            let answerIndex = updatedQuestion.answers.firstIndex(where: { $0.id == answerId })
        else {
            return
        }

        let originalAnswer = updatedQuestion.answers[answerIndex]
        likingAnswerIds.insert(answerId)
        defer { likingAnswerIds.remove(answerId) }

        updatedQuestion.answers[answerIndex].isLiked.toggle()
        updatedQuestion.answers[answerIndex].likesCount = max(
            0,
            originalAnswer.likesCount + (originalAnswer.isLiked ? -1 : 1)
        )
        question = updatedQuestion

        let result = await answerService.toggleLike(
            answerId: answerId,
            isLiked: originalAnswer.isLiked
        )

        guard
            var latestQuestion = question,
            let latestAnswerIndex = latestQuestion.answers.firstIndex(where: { $0.id == answerId })
        else {
            return
        }

        switch result {
        case .success(let updatedLikesCount):
            if let updatedLikesCount {
                latestQuestion.answers[latestAnswerIndex].likesCount = updatedLikesCount
                question = latestQuestion
            }
            notifyAnswerLikeChanged(answerId: answerId)
        case .failure:
            latestQuestion.answers[latestAnswerIndex] = originalAnswer
            question = latestQuestion
            showToast(.likeFailed)
        }
    }

    private func requestAnswerDeletion(answerId: Int) {
        guard
            !isAnswerDeleteConfirmationPresented,
            !deletingAnswerIds.contains(answerId),
            let answer = question?.answers.first(where: { $0.id == answerId }),
            answer.isOwnedByCurrentUser
        else {
            return
        }

        answerPendingDeletion = answer
        isAnswerDeleteConfirmationPresented = true
    }

    private func confirmAnswerDeletion() async {
        guard
            let answer = answerPendingDeletion,
            !deletingAnswerIds.contains(answer.id)
        else {
            return
        }

        isAnswerDeleteConfirmationPresented = false
        answerPendingDeletion = nil
        deletingAnswerIds.insert(answer.id)
        defer { deletingAnswerIds.remove(answer.id) }

        let result = await answerService.deleteAnswer(answerId: answer.id)

        switch result {
        case .success:
            removeAnswer(answerId: answer.id)
            NotificationCenter.default.post(
                name: .answerDeleted,
                object: nil,
                userInfo: [
                    AnswerDeletionNotification.answerIdKey: answer.id
                ]
            )
        case .failure:
            showToast(.deleteAnswerFailed)
        }
    }

    private func toggleBestAnswer(answerId: Int) async {
        guard
            !updatingBestAnswerIds.contains(answerId),
            let currentQuestion = question,
            currentQuestion.isOwnedByCurrentUser,
            let answerIndex = currentQuestion.answers.firstIndex(where: { $0.id == answerId })
        else {
            return
        }

        let originalAnswers = currentQuestion.answers
        updatingBestAnswerIds.insert(answerId)
        defer { updatingBestAnswerIds.remove(answerId) }

        let shouldMarkBest = !currentQuestion.answers[answerIndex].isBest
        applyBestAnswer(answerId: answerId, isBest: shouldMarkBest)

        let result = await answerService.markBestAnswer(
            questionId: questionId,
            answerId: answerId,
            isBest: shouldMarkBest
        )

        switch result {
        case .success:
            notifyBestAnswerChanged(answerId: answerId, isBest: shouldMarkBest)
        case .failure:
            guard var updatedQuestion = question else { return }

            updatedQuestion.answers = originalAnswers
            question = updatedQuestion
            showToast(.markBestAnswerFailed)
        }
    }

    private func removeAnswer(answerId: Int) {
        guard var updatedQuestion = question else { return }

        let originalCount = updatedQuestion.answers.count
        updatedQuestion.answers.removeAll { $0.id == answerId }

        guard updatedQuestion.answers.count != originalCount else { return }

        updatedQuestion.answersCount = max(0, updatedQuestion.answersCount - 1)
        question = updatedQuestion
    }

    private func applyAnswerPublished(questionId: Int) {
        guard var updatedQuestion = question, updatedQuestion.id == questionId else { return }

        updatedQuestion.answersCount += 1
        question = updatedQuestion
    }

    private func refreshAnsweredQuestion(questionId: Int) async {
        guard questionId == self.questionId, !isLoading else { return }

        let result = await questionService.getQuestionDetails(
            questionId: questionId,
            batchSize: Self.batchSize
        )

        switch result {
        case .success(let updatedQuestion):
            question = updatedQuestion
            latestAnswerId = updatedQuestion.answers.last?.id
            hasMoreAnswers = updatedQuestion.answers.count < updatedQuestion.answersCount
            lastQuestionLoadedAt = Date()
            state = .content
        case .failure:
            applyAnswerPublished(questionId: questionId)
        }
    }

    private func applyAnswerLikeChanged(answerId: Int, isLiked: Bool, likesCount: Int) {
        guard
            var updatedQuestion = question,
            let answerIndex = updatedQuestion.answers.firstIndex(where: { $0.id == answerId })
        else {
            return
        }

        updatedQuestion.answers[answerIndex].isLiked = isLiked
        updatedQuestion.answers[answerIndex].likesCount = likesCount
        question = updatedQuestion
    }

    private func applyBestAnswer(answerId: Int, isBest: Bool) {
        guard var updatedQuestion = question else { return }

        if isBest {
            for index in updatedQuestion.answers.indices {
                updatedQuestion.answers[index].isBest = false
            }
        }

        if let answerIndex = updatedQuestion.answers.firstIndex(where: { $0.id == answerId }) {
            updatedQuestion.answers[answerIndex].isBest = isBest
        }
        question = updatedQuestion
    }

    private func confirmQuestionDeletion() async {
        guard
            state != .deleting,
            let question,
            question.isOwnedByCurrentUser
        else {
            return
        }

        isDeleteConfirmationPresented = false
        state = .deleting

        let result = await questionService.deleteQuestion(
            questionId: question.id,
            authorId: question.authorId
        )

        switch result {
        case .success:
            shouldDismiss = true
        case .failure:
            state = .content
            toast = ToastMessage.deleteQuestionFailed.item
        }
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }

    private func notifyBestAnswerChanged(answerId: Int, isBest: Bool) {
        NotificationCenter.default.post(
            name: .bestAnswerChanged,
            object: nil,
            userInfo: [
                BestAnswerNotification.questionIdKey: questionId,
                BestAnswerNotification.answerIdKey: answerId,
                BestAnswerNotification.isBestKey: isBest
            ]
        )
    }

    private func notifyAnswerLikeChanged(answerId: Int) {
        guard let answer = question?.answers.first(where: { $0.id == answerId }) else { return }

        NotificationCenter.default.post(
            name: .answerLikeChanged,
            object: nil,
            userInfo: [
                AnswerLikeNotification.answerIdKey: answer.id,
                AnswerLikeNotification.isLikedKey: answer.isLiked,
                AnswerLikeNotification.likesCountKey: answer.likesCount
            ]
        )
    }
}
