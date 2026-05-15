import SwiftUI
import Core
import Networking
import Combine

@MainActor
@Observable
final class ProfileQuestionsSectionViewModel {

    // MARK: - Internal Types

    enum Intent {

        // MARK: Feed
        case loadFeed
        case refreshFeed
        case invalidateFeed
        case userNickChanged(String)
        case loadNextBatchIfNeeded(questionId: Int)

        // MARK: Navigation
        case openUserProfile(userNick: String)
        case openQuestionDetails(question: Question)

        // MARK: Reporting
        case reportSent

        // MARK: Questions
        case requestQuestionDeletion(questionId: Int)
        case dismissQuestionDeletion
        case cancelQuestionDeletion
        case confirmQuestionDeletion

        // MARK: Answers
        case answerPublished(questionId: Int)
        case toggleAnswerLike(answerId: Int)
        case toggleBestAnswer(questionId: Int, answerId: Int)
        case bestAnswerChanged(questionId: Int, answerId: Int, isBest: Bool)
        case requestAnswerDeletion(answerId: Int)
        case dismissAnswerDeletion
        case cancelAnswerDeletion
        case confirmAnswerDeletion

        // MARK: Toast
        case dismissToast
    }

    enum State: Equatable {
        case loadingFeed
        case loadingNextBatch
        case refreshingFeed
        case content
        case empty
        case error(String?)
    }

    // MARK: - Properties

    private(set) var state: State = .empty
    private(set) var toast: ToastItem?
    private(set) var questions: [Question] = []
    private(set) var questionPendingDeletion: Question?
    private(set) var isDeleteConfirmationPresented = false
    private(set) var answerPendingDeletion: Answer?
    private(set) var isAnswerDeleteConfirmationPresented = false

    private var hasMoreQuestions = true
    private var latestQuestionId = maxQuestionId
    private var lastFeedLoadedAt: Date?
    private var likingAnswerIds = Set<Int>()
    private var updatingBestAnswerIds = Set<Int>()
    private var deletingAnswerIds = Set<Int>()
    private var deletingQuestionIds = Set<Int>()
    private var notificationCancellables = Set<AnyCancellable>()

    private var userNick: String
    private let isOwnProfile: Bool
    private let questionService: QuestionService
    private let answerService: AnswerService
    private let onAuthorTap: ((String) -> Void)?
    private let onQuestionTap: ((Question) -> Void)?

    private static let batchSize = 5
    private static let maxQuestionId = 999999999
    private static let feedRefreshInterval: TimeInterval = 2 * 60

    private var feedMode: QuestionsFeedMode {
        isOwnProfile ? .my : .nick
    }

    private var isLoading: Bool {
        state == .loadingFeed || state == .refreshingFeed || state == .loadingNextBatch
    }

    private var isRefreshing: Bool {
        lastFeedLoadedAt != nil
    }

    private var shouldUpdateData: Bool {
        guard let lastFeedLoadedAt else { return true }
        return Date().timeIntervalSince(lastFeedLoadedAt) > Self.feedRefreshInterval
    }

    // MARK: - Internal Init

    init(
        userNick: String,
        isOwnProfile: Bool,
        questionService: QuestionService = QuestionService(),
        answerService: AnswerService = AnswerService(),
        onAuthorTap: ((String) -> Void)?,
        onQuestionTap: ((Question) -> Void)?
    ) {
        self.userNick = userNick
        self.isOwnProfile = isOwnProfile
        self.questionService = questionService
        self.answerService = answerService
        self.onAuthorTap = onAuthorTap
        self.onQuestionTap = onQuestionTap

        observeNotifications()
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .loadFeed:
            Task { await loadFeed() }
        case .refreshFeed:
            Task { await loadFeed(force: true) }
        case .invalidateFeed:
            lastFeedLoadedAt = nil
        case .userNickChanged(let userNick):
            self.userNick = userNick
            lastFeedLoadedAt = nil
        case .loadNextBatchIfNeeded(let questionId):
            guard questionId == latestQuestionId else { return }
            Task { await loadNextBatch() }
        case .openUserProfile(let authorNick):
            guard authorNick != userNick else { return }
            onAuthorTap?(authorNick)
        case .openQuestionDetails(let question):
            onQuestionTap?(question)
        case .reportSent:
            toast = ToastMessage.reportSent.item
        case .requestQuestionDeletion(let questionId):
            requestQuestionDeletion(questionId: questionId)
        case .dismissQuestionDeletion:
            isDeleteConfirmationPresented = false
        case .cancelQuestionDeletion:
            isDeleteConfirmationPresented = false
            questionPendingDeletion = nil
        case .confirmQuestionDeletion:
            Task { await confirmQuestionDeletion() }
        case .answerPublished(let questionId):
            notifyAnswerPublished(questionId: questionId)
        case .toggleAnswerLike(let answerId):
            Task { await toggleAnswerLike(answerId: answerId) }
        case .toggleBestAnswer(let questionId, let answerId):
            Task { await toggleBestAnswer(questionId: questionId, answerId: answerId) }
        case .bestAnswerChanged(let questionId, let answerId, let isBest):
            applyBestAnswer(questionId: questionId, answerId: answerId, isBest: isBest)
        case .requestAnswerDeletion(let answerId):
            requestAnswerDeletion(answerId: answerId)
        case .dismissAnswerDeletion:
            isAnswerDeleteConfirmationPresented = false
        case .cancelAnswerDeletion:
            isAnswerDeleteConfirmationPresented = false
            answerPendingDeletion = nil
        case .confirmAnswerDeletion:
            Task { await confirmAnswerDeletion() }
        case .dismissToast:
            toast = nil
        }
    }

    func shouldDisableAnswerActions(questionId: Int, answerId: Int) -> Bool {
        likingAnswerIds.contains(answerId)
        || deletingAnswerIds.contains(answerId)
        || updatingBestAnswerIds.contains(answerId)
        || deletingQuestionIds.contains(questionId)
    }
}

// MARK: - Feed

private extension ProfileQuestionsSectionViewModel {

    func loadFeed(force: Bool = false) async {
        guard !isLoading, force || shouldUpdateData else { return }

        state = isRefreshing ? .refreshingFeed : .loadingFeed

        let result = await questionService.getQuestionsFeed(
            for: userNick,
            questionId: Self.maxQuestionId,
            batchSize: Self.batchSize,
            mode: feedMode
        )

        switch result {
        case .success(let loadedQuestions):
            questions = QuestionAnswerPreview.limitedQuestions(loadedQuestions)
            latestQuestionId = questions.map(\.id).min() ?? Self.maxQuestionId
            hasMoreQuestions = questions.count == Self.batchSize
            lastFeedLoadedAt = Date()
            state = questions.isEmpty ? .empty : .content
        case .failure(let error):
            if isRefreshing {
                state = .content
                showToast(.refreshFailed)
            } else {
                state = .error(error.localizedDescription)
            }
        }
    }

    func loadNextBatch() async {
        guard state == .content, hasMoreQuestions else { return }

        state = .loadingNextBatch

        let result = await questionService.getQuestionsFeed(
            for: userNick,
            questionId: latestQuestionId,
            batchSize: Self.batchSize,
            mode: feedMode
        )

        switch result {
        case .success(let loadedQuestions):
            questions.append(contentsOf: QuestionAnswerPreview.limitedQuestions(loadedQuestions))
            latestQuestionId = loadedQuestions.map(\.id).min() ?? Self.maxQuestionId
            hasMoreQuestions = loadedQuestions.count == Self.batchSize
            lastFeedLoadedAt = Date()
            state = .content
        case .failure:
            state = .content
            showToast(.nextBatchLoadFailed)
        }
    }

    func refreshAnsweredQuestion(questionId: Int) async {
        guard questions.contains(where: { $0.id == questionId }) else { return }

        let result = await questionService.getQuestionDetails(
            questionId: questionId,
            batchSize: Self.batchSize
        )

        switch result {
        case .success(let updatedQuestion):
            replaceQuestion(updatedQuestion)
        case .failure:
            applyAnswerPublished(questionId: questionId)
        }
    }
}

// MARK: - Question Actions

private extension ProfileQuestionsSectionViewModel {

    func requestQuestionDeletion(questionId: Int) {
        guard !isDeleteConfirmationPresented,
              !deletingQuestionIds.contains(questionId),
              let question = questions.first(where: { $0.id == questionId }),
              question.isOwnedByCurrentUser
        else {
            return
        }

        questionPendingDeletion = question
        isDeleteConfirmationPresented = true
    }

    func confirmQuestionDeletion() async {
        guard let question = questionPendingDeletion,
              !deletingQuestionIds.contains(question.id)
        else {
            return
        }

        isDeleteConfirmationPresented = false
        questionPendingDeletion = nil
        deletingQuestionIds.insert(question.id)
        defer { deletingQuestionIds.remove(question.id) }

        let result = await questionService.deleteQuestion(
            questionId: question.id,
            authorId: question.authorId
        )

        switch result {
        case .success:
            removeQuestion(questionId: question.id)
            notifyQuestionDeleted(question: question)
        case .failure:
            showToast(.deleteQuestionFailed)
        }
    }
}

// MARK: - Answer Actions

private extension ProfileQuestionsSectionViewModel {

    func toggleAnswerLike(answerId: Int) async {
        guard !likingAnswerIds.contains(answerId) else { return }

        var updatedQuestions = questions
        guard let indexes = answerIndexes(answerId: answerId, in: updatedQuestions) else { return }

        likingAnswerIds.insert(answerId)
        defer { likingAnswerIds.remove(answerId) }

        let originalAnswer = updatedQuestions[indexes.question].answers[indexes.answer]
        updatedQuestions[indexes.question].answers[indexes.answer].isLiked.toggle()
        updatedQuestions[indexes.question].answers[indexes.answer].likesCount = max(
            0,
            originalAnswer.likesCount + (originalAnswer.isLiked ? -1 : 1)
        )
        questions = updatedQuestions

        let result = await answerService.toggleLike(
            answerId: answerId,
            isLiked: originalAnswer.isLiked
        )

        switch result {
        case .success(let updatedLikesCount):
            if let updatedLikesCount {
                var latestQuestions = questions
                guard let indexes = answerIndexes(answerId: answerId, in: latestQuestions) else { return }

                latestQuestions[indexes.question].answers[indexes.answer].likesCount = updatedLikesCount
                questions = latestQuestions
            }
            notifyAnswerLikeChanged(answerId: answerId)
        case .failure:
            var latestQuestions = questions
            if let indexes = answerIndexes(answerId: answerId, in: latestQuestions) {
                latestQuestions[indexes.question].answers[indexes.answer] = originalAnswer
                questions = latestQuestions
            }
            showToast(.likeFailed)
        }
    }

    func toggleBestAnswer(questionId: Int, answerId: Int) async {
        guard !updatingBestAnswerIds.contains(answerId),
              let question = questions.first(where: { $0.id == questionId }),
              question.isOwnedByCurrentUser,
              let answerIndex = question.answers.firstIndex(where: { $0.id == answerId })
        else {
            return
        }

        updatingBestAnswerIds.insert(answerId)
        defer { updatingBestAnswerIds.remove(answerId) }

        let originalAnswers = question.answers
        let shouldMarkBest = !question.answers[answerIndex].isBest
        applyBestAnswer(questionId: questionId, answerId: answerId, isBest: shouldMarkBest)

        let result = await answerService.markBestAnswer(
            questionId: questionId,
            answerId: answerId,
            isBest: shouldMarkBest
        )

        switch result {
        case .success:
            notifyBestAnswerChanged(
                questionId: questionId,
                answerId: answerId,
                isBest: shouldMarkBest
            )
        case .failure:
            var updatedQuestions = questions
            if let questionIndex = updatedQuestions.firstIndex(where: { $0.id == questionId }) {
                updatedQuestions[questionIndex].answers = originalAnswers
                questions = updatedQuestions
            }
            showToast(.markBestAnswerFailed)
        }
    }

    func requestAnswerDeletion(answerId: Int) {
        guard !isAnswerDeleteConfirmationPresented,
              !deletingAnswerIds.contains(answerId),
              let answer = answer(answerId: answerId),
              answer.isOwnedByCurrentUser
        else {
            return
        }

        answerPendingDeletion = answer
        isAnswerDeleteConfirmationPresented = true
    }

    func confirmAnswerDeletion() async {
        guard let answer = answerPendingDeletion,
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
            notifyAnswerDeleted(answerId: answer.id)
        case .failure:
            showToast(.deleteAnswerFailed)
        }
    }
}

// MARK: - State Mutations

private extension ProfileQuestionsSectionViewModel {

    func removeQuestion(questionId: Int) {
        questions.removeAll { $0.id == questionId }
        state = questions.isEmpty ? .empty : .content
    }

    func removeAnswer(answerId: Int) {
        var updatedQuestions = questions

        for questionIndex in updatedQuestions.indices {
            let originalCount = updatedQuestions[questionIndex].answers.count
            updatedQuestions[questionIndex].answers.removeAll { $0.id == answerId }

            if updatedQuestions[questionIndex].answers.count != originalCount {
                updatedQuestions[questionIndex].answersCount = max(
                    0,
                    updatedQuestions[questionIndex].answersCount - 1
                )
            }
        }

        questions = updatedQuestions
    }

    func applyAnswerPublished(questionId: Int) {
        guard let questionIndex = questions.firstIndex(where: { $0.id == questionId }) else { return }

        questions[questionIndex].answersCount += 1
    }

    func replaceQuestion(_ updatedQuestion: Question) {
        guard let questionIndex = questions.firstIndex(where: { $0.id == updatedQuestion.id }) else { return }

        questions[questionIndex] = QuestionAnswerPreview.limitedQuestion(updatedQuestion)
    }

    func applyBestAnswer(
        questionId: Int,
        answerId: Int,
        isBest: Bool
    ) {
        var updatedQuestions = questions

        guard let questionIndex = updatedQuestions.firstIndex(where: { $0.id == questionId }) else { return }

        if isBest {
            for answerIndex in updatedQuestions[questionIndex].answers.indices {
                updatedQuestions[questionIndex].answers[answerIndex].isBest = false
            }
        }

        if let answerIndex = updatedQuestions[questionIndex].answers.firstIndex(where: { $0.id == answerId }) {
            updatedQuestions[questionIndex].answers[answerIndex].isBest = isBest
        }

        questions = updatedQuestions
    }

    func applyAnswerLikeChanged(answerId: Int, isLiked: Bool, likesCount: Int) {
        var updatedQuestions = questions
        guard let indexes = answerIndexes(answerId: answerId, in: updatedQuestions) else { return }

        updatedQuestions[indexes.question].answers[indexes.answer].isLiked = isLiked
        updatedQuestions[indexes.question].answers[indexes.answer].likesCount = likesCount
        questions = updatedQuestions
    }
}

// MARK: - Search

private extension ProfileQuestionsSectionViewModel {

    func answer(answerId: Int) -> Answer? {
        questions.lazy
            .flatMap(\.answers)
            .first { $0.id == answerId }
    }

    func answerIndexes(answerId: Int, in questions: [Question]) -> (question: Int, answer: Int)? {
        for questionIndex in questions.indices {
            guard let answerIndex = questions[questionIndex].answers.firstIndex(where: { $0.id == answerId }) else {
                continue
            }
            return (questionIndex, answerIndex)
        }

        return nil
    }
}

// MARK: - Notifications

private extension ProfileQuestionsSectionViewModel {

    func observeNotifications() {
        NotificationCenter.default
            .publisher(for: .questionDeleted)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handleQuestionDeletedNotification(notification)
                }
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default
            .publisher(for: .answerDeleted)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handleAnswerDeletedNotification(notification)
                }
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default
            .publisher(for: .answerPublished)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handleAnswerPublishedNotification(notification)
                }
            }
            .store(in: &notificationCancellables)

        NotificationCenter.default
            .publisher(for: .answerLikeChanged)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handleAnswerLikeChangedNotification(notification)
                }
            }
            .store(in: &notificationCancellables)
    }

    func handleQuestionDeletedNotification(_ notification: Notification) {
        guard let questionId = notification.userInfo?[QuestionDeletionNotification.questionIdKey] as? Int else {
            return
        }

        removeQuestion(questionId: questionId)
    }

    func handleAnswerDeletedNotification(_ notification: Notification) {
        guard let answerId = notification.userInfo?[AnswerDeletionNotification.answerIdKey] as? Int else {
            return
        }

        removeAnswer(answerId: answerId)
    }

    func handleAnswerPublishedNotification(_ notification: Notification) {
        guard let questionId = notification.userInfo?[AnswerPublishedNotification.questionIdKey] as? Int else {
            return
        }

        Task { await refreshAnsweredQuestion(questionId: questionId) }
    }

    func handleAnswerLikeChangedNotification(_ notification: Notification) {
        guard let answerId = notification.userInfo?[AnswerLikeNotification.answerIdKey] as? Int,
              let isLiked = notification.userInfo?[AnswerLikeNotification.isLikedKey] as? Bool,
              let likesCount = notification.userInfo?[AnswerLikeNotification.likesCountKey] as? Int
        else {
            return
        }

        applyAnswerLikeChanged(answerId: answerId, isLiked: isLiked, likesCount: likesCount)
    }

    func notifyQuestionDeleted(question: Question) {
        NotificationCenter.default.post(
            name: .questionDeleted,
            object: nil,
            userInfo: [
                QuestionDeletionNotification.questionIdKey: question.id,
                QuestionDeletionNotification.authorNickKey: question.authorNick
            ]
        )
    }

    func notifyAnswerDeleted(answerId: Int) {
        NotificationCenter.default.post(
            name: .answerDeleted,
            object: nil,
            userInfo: [
                AnswerDeletionNotification.answerIdKey: answerId
            ]
        )
    }

    func notifyAnswerPublished(questionId: Int) {
        NotificationCenter.default.post(
            name: .answerPublished,
            object: nil,
            userInfo: [
                AnswerPublishedNotification.questionIdKey: questionId
            ]
        )
    }

    func notifyBestAnswerChanged(
        questionId: Int,
        answerId: Int,
        isBest: Bool
    ) {
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

    func notifyAnswerLikeChanged(answerId: Int) {
        guard let answer = answer(answerId: answerId) else { return }

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

// MARK: - Toast

private extension ProfileQuestionsSectionViewModel {

    func showToast(_ message: ToastMessage) {
        toast = message.item
    }
}
