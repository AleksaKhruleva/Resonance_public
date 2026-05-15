import SwiftUI
import Networking
import Core
import Combine

@MainActor
@Observable
final class QuestionsFeedViewModel {

    // MARK: - Internal Types

    enum Intent {

        // MARK: Feed
        case loadFeed
        case refreshFeed
        case refreshFeedIfNeeded(trigger: Int, filter: FeedFilter?)
        case loadNextBatchIfNeeded(questionId: Int)
        case selectFilter(FeedFilter)

        // MARK: Navigation
        case openUserProfile(userNick: String)
        case openQuestionDetails(question: Question)
        case openNotifications

        // MARK: Answers
        case answerPublished(questionId: Int)
        case toggleAnswerLike(answerId: Int)
        case requestAnswerDeletion(answerId: Int)
        case dismissAnswerDeletion
        case cancelAnswerDeletion
        case confirmAnswerDeletion
        case toggleBestAnswer(questionId: Int, answerId: Int)
        case bestAnswerChanged(questionId: Int, answerId: Int, isBest: Bool)

        // MARK: Questions
        case requestQuestionDeletion(questionId: Int)
        case dismissQuestionDeletion
        case cancelQuestionDeletion
        case confirmQuestionDeletion

        // MARK: Toast
        case reportSent
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

    private struct FeedStorage {
        var questions: [Question] = []
        var hasMoreQuestions = true
        var latestQuestionId: Int
        var lastFeedLoadedAt: Date?
        var loadingKind: LoadingKind?
        var hasError = false
        var errorDescription: String?
    }

    private enum LoadingKind {
        case feed
        case nextBatch
    }

    // MARK: - Properties

    private(set) var toast: ToastItem?

    private(set) var state: State = .empty
    private(set) var questions: [Question] = []
    private(set) var selectedFilter: FeedFilter = .all
    private(set) var questionPendingDeletion: Question?
    private(set) var isDeleteConfirmationPresented = false
    private(set) var answerPendingDeletion: Answer?
    private(set) var isAnswerDeleteConfirmationPresented = false

    private var feedStorageByFilter: [FeedFilter: FeedStorage]
    private var likingAnswerIds = Set<Int>()
    private var deletingAnswerIds = Set<Int>()
    private var updatingBestAnswerIds = Set<Int>()
    private var deletingQuestionIds = Set<Int>()
    private var handledRefreshTrigger = 0
    private var notificationCancellables = Set<AnyCancellable>()

    private let questionService: QuestionService
    private let answerService: AnswerService
    private let onAuthorTap: ((String) -> Void)?
    private let onQuestionTap: ((Question) -> Void)?
    private let onNotificationsTap: (() -> Void)?

    private static let batchSize = 10
    private static let maxQuestionId = 999999999
    private static let feedRefreshInterval: TimeInterval = 2 * 60

    private var currentStorage: FeedStorage {
        feedStorageByFilter[selectedFilter] ?? FeedStorage(latestQuestionId: Self.maxQuestionId)
    }

    private var shouldUpdateData: Bool {
        guard let lastFeedLoadedAt = currentStorage.lastFeedLoadedAt else { return true }
        return Date().timeIntervalSince(lastFeedLoadedAt) > Self.feedRefreshInterval
    }

    // MARK: - Internal Init

    init(
        questionService: QuestionService = QuestionService(),
        answerService: AnswerService = AnswerService(),
        onAuthorTap: ((String) -> Void)?,
        onQuestionTap: ((Question) -> Void)?,
        onNotificationsTap: (() -> Void)? = nil
    ) {
        self.questionService = questionService
        self.answerService = answerService
        self.feedStorageByFilter = Dictionary(
            uniqueKeysWithValues: FeedFilter.allCases.map {
                ($0, FeedStorage(latestQuestionId: Self.maxQuestionId))
            }
        )
        self.onAuthorTap = onAuthorTap
        self.onQuestionTap = onQuestionTap
        self.onNotificationsTap = onNotificationsTap
        observeNotifications()
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .loadFeed:
            Task { await loadFeed(for: selectedFilter) }
        case .refreshFeed:
            Task { await loadFeed(for: selectedFilter, forcedUpdate: true) }
        case .refreshFeedIfNeeded(let trigger, let filter):
            refreshFeedIfNeeded(trigger: trigger, filter: filter)
        case .loadNextBatchIfNeeded(let questionId):
            guard questionId == currentStorage.latestQuestionId else { return }
            Task { await loadNextBatch(for: selectedFilter) }
        case .selectFilter(let filter):
            guard selectedFilter != filter else { return }
            selectedFilter = filter
            applyCurrentStorage()
            guard shouldUpdateData else { return }
            Task { await loadFeed(for: filter) }
        case .openUserProfile(let authorNick):
            onAuthorTap?(authorNick)
        case .openQuestionDetails(let question):
            onQuestionTap?(question)
        case .openNotifications:
            onNotificationsTap?()
        case .answerPublished(let questionId):
            notifyAnswerPublished(questionId: questionId)
        case .toggleAnswerLike(let answerId):
            Task { await toggleAnswerLike(answerId: answerId, filter: selectedFilter) }
        case .requestAnswerDeletion(let answerId):
            requestAnswerDeletion(answerId: answerId)
        case .dismissAnswerDeletion:
            isAnswerDeleteConfirmationPresented = false
        case .cancelAnswerDeletion:
            isAnswerDeleteConfirmationPresented = false
            answerPendingDeletion = nil
        case .confirmAnswerDeletion:
            Task { await confirmAnswerDeletion() }
        case .toggleBestAnswer(let questionId, let answerId):
            Task { await toggleBestAnswer(questionId: questionId, answerId: answerId) }
        case .bestAnswerChanged(let questionId, let answerId, let isBest):
            applyBestAnswer(questionId: questionId, answerId: answerId, isBest: isBest)
        case .requestQuestionDeletion(let questionId):
            requestQuestionDeletion(questionId: questionId)
        case .dismissQuestionDeletion:
            isDeleteConfirmationPresented = false
        case .cancelQuestionDeletion:
            isDeleteConfirmationPresented = false
            questionPendingDeletion = nil
        case .confirmQuestionDeletion:
            Task { await confirmQuestionDeletion() }
        case .reportSent:
            toast = ToastMessage.reportSent.item
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

private extension QuestionsFeedViewModel {

    func refreshFeedIfNeeded(trigger: Int, filter: FeedFilter?) {
        guard trigger != handledRefreshTrigger else { return }
        handledRefreshTrigger = trigger

        if let filter, selectedFilter != filter {
            selectedFilter = filter
            applyCurrentStorage()
        }

        Task { await loadFeed(for: selectedFilter, forcedUpdate: true) }
    }

    func loadFeed(for filter: FeedFilter, forcedUpdate: Bool = false) async {
        var storage = feedStorage(for: filter)
        guard storage.loadingKind == nil else { return }
        guard shouldUpdateData(for: storage) || forcedUpdate else { return }

        storage.loadingKind = .feed
        storage.hasError = false
        setStorage(storage, for: filter)
        applyStorageIfNeeded(for: filter)

        let result = await questionService.getQuestionsFeed(
            questionId: Self.maxQuestionId,
            batchSize: Self.batchSize,
            mode: filter.mode
        )

        switch result {
        case .success(let loadedQuestions):
            var storage = feedStorage(for: filter)
            storage.questions = QuestionAnswerPreview.limitedQuestions(loadedQuestions)
            storage.latestQuestionId = loadedQuestions.map(\.id).min() ?? Self.maxQuestionId
            storage.hasMoreQuestions = loadedQuestions.count == Self.batchSize
            storage.lastFeedLoadedAt = Date()
            storage.loadingKind = nil
            storage.hasError = false
            setStorage(storage, for: filter)

            applyStorageIfNeeded(for: filter)
        case .failure(let error):
            var storage = feedStorage(for: filter)
            storage.loadingKind = nil
            storage.hasError = true
            storage.errorDescription = error.localizedDescription
            setStorage(storage, for: filter)
            applyStorageIfNeeded(for: filter)
            if !storage.questions.isEmpty {
                showToastIfNeeded(.refreshFailed, for: filter)
            }
        }
    }

    func loadNextBatch(for filter: FeedFilter) async {
        var storage = feedStorage(for: filter)
        guard storage.loadingKind == nil, storage.hasMoreQuestions, !storage.questions.isEmpty else { return }

        let latestQuestionId = storage.latestQuestionId
        storage.loadingKind = .nextBatch
        storage.hasError = false
        setStorage(storage, for: filter)
        applyStorageIfNeeded(for: filter)

        let result = await questionService.getQuestionsFeed(
            questionId: latestQuestionId,
            batchSize: Self.batchSize,
            mode: filter.mode
        )

        switch result {
        case .success(let loadedQuestions):
            var storage = feedStorage(for: filter)
            storage.questions.append(contentsOf: QuestionAnswerPreview.limitedQuestions(loadedQuestions))
            storage.latestQuestionId = loadedQuestions.map(\.id).min() ?? latestQuestionId
            storage.hasMoreQuestions = loadedQuestions.count == Self.batchSize
            storage.lastFeedLoadedAt = Date()
            storage.loadingKind = nil
            storage.hasError = false
            setStorage(storage, for: filter)

            applyStorageIfNeeded(for: filter)
        case .failure(let error):
            var storage = feedStorage(for: filter)
            storage.loadingKind = nil
            storage.hasError = true
            storage.errorDescription = error.localizedDescription
            setStorage(storage, for: filter)
            applyStorageIfNeeded(for: filter)
            showToastIfNeeded(.nextBatchLoadFailed, for: filter)
        }
    }

    func refreshAnsweredQuestion(questionId: Int) async {
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

// MARK: - Answer Actions

private extension QuestionsFeedViewModel {

    func toggleAnswerLike(answerId: Int, filter: FeedFilter) async {
        guard
            !likingAnswerIds.contains(answerId),
            var storage = feedStorageByFilter[filter],
            let indexes = answerIndexes(answerId: answerId, in: storage.questions)
        else {
            return
        }

        likingAnswerIds.insert(answerId)
        defer { likingAnswerIds.remove(answerId) }

        let originalAnswer = storage.questions[indexes.question].answers[indexes.answer]
        storage.questions = updatedQuestions(storage.questions, answerId: answerId) { answer in
            answer.isLiked.toggle()
            answer.likesCount = max(
                0,
                originalAnswer.likesCount + (originalAnswer.isLiked ? -1 : 1)
            )
        } ?? storage.questions
        setStorage(storage, for: filter)
        applyStorageIfNeeded(for: filter)

        let result = await answerService.toggleLike(
            answerId: answerId,
            isLiked: originalAnswer.isLiked
        )

        guard var latestStorage = feedStorageByFilter[filter] else { return }

        switch result {
        case .success(let updatedLikesCount):
            if let updatedLikesCount {
                latestStorage.questions = updatedQuestions(latestStorage.questions, answerId: answerId) { answer in
                    answer.likesCount = updatedLikesCount
                } ?? latestStorage.questions
                setStorage(latestStorage, for: filter)
                applyStorageIfNeeded(for: filter)
            }
            notifyAnswerLikeChanged(answerId: answerId, filter: filter)
        case .failure:
            if latestStorage.questions.contains(where: { question in
                question.answers.contains { $0.id == answerId }
            }) {
                latestStorage.questions = updatedQuestions(latestStorage.questions, answerId: answerId) { answer in
                    answer = originalAnswer
                } ?? latestStorage.questions
                setStorage(latestStorage, for: filter)
                applyStorageIfNeeded(for: filter)
            }
            showToastIfNeeded(.likeFailed, for: filter)
        }
    }

    func requestAnswerDeletion(answerId: Int) {
        guard
            !isAnswerDeleteConfirmationPresented,
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
            notifyAnswerDeleted(answerId: answer.id)
        case .failure:
            showToast(.deleteAnswerFailed)
        }
    }

    func toggleBestAnswer(questionId: Int, answerId: Int) async {
        guard
            !updatingBestAnswerIds.contains(answerId),
            let question = questions.first(where: { $0.id == questionId }),
            question.isOwnedByCurrentUser,
            let answer = question.answers.first(where: { $0.id == answerId })
        else {
            return
        }

        updatingBestAnswerIds.insert(answerId)
        defer { updatingBestAnswerIds.remove(answerId) }

        let originalStorageByFilter = feedStorageByFilter
        let shouldMarkBest = !answer.isBest
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
            feedStorageByFilter = originalStorageByFilter
            applyCurrentStorage()
            showToast(.markBestAnswerFailed)
        }
    }
}

// MARK: - Question Actions

private extension QuestionsFeedViewModel {

    func requestQuestionDeletion(questionId: Int) {
        guard
            !isDeleteConfirmationPresented,
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
        guard
            let question = questionPendingDeletion,
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

// MARK: - State Mutations

private extension QuestionsFeedViewModel {

    func removeQuestion(questionId: Int) {
        for filter in FeedFilter.allCases {
            var storage = feedStorage(for: filter)
            storage.questions.removeAll { $0.id == questionId }
            setStorage(storage, for: filter)
        }
        applyCurrentStorage()
    }

    func applyAnswerLikeChanged(answerId: Int, isLiked: Bool, likesCount: Int) {
        for filter in FeedFilter.allCases {
            var storage = feedStorage(for: filter)
            storage.questions = updatedQuestions(storage.questions, answerId: answerId) { answer in
                answer.isLiked = isLiked
                answer.likesCount = likesCount
            } ?? storage.questions
            setStorage(storage, for: filter)
        }

        applyCurrentStorage()
    }

    func removeAnswer(answerId: Int) {
        for filter in FeedFilter.allCases {
            var storage = feedStorage(for: filter)

            for questionIndex in storage.questions.indices {
                var question = storage.questions[questionIndex]
                let originalCount = question.answers.count
                question.answers.removeAll { $0.id == answerId }

                if question.answers.count != originalCount {
                    question.answersCount = max(
                        0,
                        question.answersCount - 1
                    )
                    storage.questions[questionIndex] = question
                }
            }

            setStorage(storage, for: filter)
        }

        applyCurrentStorage()
    }

    func applyAnswerPublished(questionId: Int) {
        for filter in FeedFilter.allCases {
            var storage = feedStorage(for: filter)
            guard let questionIndex = storage.questions.firstIndex(where: { $0.id == questionId }) else {
                continue
            }

            storage.questions[questionIndex].answersCount += 1
            setStorage(storage, for: filter)
        }

        applyCurrentStorage()
    }

    func replaceQuestion(_ updatedQuestion: Question) {
        for filter in FeedFilter.allCases {
            var storage = feedStorage(for: filter)
            guard let questionIndex = storage.questions.firstIndex(where: { $0.id == updatedQuestion.id }) else {
                continue
            }

            storage.questions[questionIndex] = QuestionAnswerPreview.limitedQuestion(updatedQuestion)
            setStorage(storage, for: filter)
        }

        applyCurrentStorage()
    }

    func applyBestAnswer(
        questionId: Int,
        answerId: Int,
        isBest: Bool
    ) {
        for filter in FeedFilter.allCases {
            var storage = feedStorage(for: filter)
            guard let questionIndex = storage.questions.firstIndex(where: { $0.id == questionId }) else {
                continue
            }

            if isBest {
                for answerIndex in storage.questions[questionIndex].answers.indices {
                    storage.questions[questionIndex].answers[answerIndex].isBest = false
                }
            }

            if let answerIndex = storage.questions[questionIndex].answers.firstIndex(where: { $0.id == answerId }) {
                storage.questions[questionIndex].answers[answerIndex].isBest = isBest
            }

            setStorage(storage, for: filter)
        }

        applyCurrentStorage()
    }
}

// MARK: - Storage

private extension QuestionsFeedViewModel {

    private func feedStorage(for filter: FeedFilter) -> FeedStorage {
        feedStorageByFilter[filter] ?? FeedStorage(latestQuestionId: Self.maxQuestionId)
    }

    private func setStorage(_ storage: FeedStorage, for filter: FeedFilter) {
        feedStorageByFilter[filter] = storage
    }

    private func shouldUpdateData(for storage: FeedStorage) -> Bool {
        guard let lastFeedLoadedAt = storage.lastFeedLoadedAt else { return true }
        return Date().timeIntervalSince(lastFeedLoadedAt) > Self.feedRefreshInterval
    }

    func applyStorageIfNeeded(for filter: FeedFilter) {
        guard selectedFilter == filter else { return }
        applyCurrentStorage()
    }

    func applyCurrentStorage() {
        let storage = currentStorage
        questions = storage.questions
        state = state(for: storage)
    }

    private func state(for storage: FeedStorage) -> State {
        switch storage.loadingKind {
        case .feed:
            return storage.questions.isEmpty ? .loadingFeed : .refreshingFeed
        case .nextBatch:
            return .loadingNextBatch
        case nil:
            if storage.hasError, storage.questions.isEmpty {
                return .error(storage.errorDescription)
            }
            return storage.questions.isEmpty ? .empty : .content
        }
    }
}

// MARK: - Answer Helpers

private extension QuestionsFeedViewModel {

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

    func updatedQuestions(
        _ questions: [Question],
        answerId: Int,
        updateAnswer: (inout Answer) -> Void
    ) -> [Question]? {
        guard let indexes = answerIndexes(answerId: answerId, in: questions) else {
            return nil
        }

        var updatedQuestions = questions
        var updatedQuestion = updatedQuestions[indexes.question]
        updateAnswer(&updatedQuestion.answers[indexes.answer])
        updatedQuestions[indexes.question] = updatedQuestion
        return updatedQuestions
    }

    func updatedQuestions(
        _ questions: [Question],
        questionId: Int,
        answerId: Int,
        updateQuestion: (inout Question, Int) -> Void
    ) -> [Question]? {
        guard let questionIndex = questions.firstIndex(where: { $0.id == questionId }) else {
            return nil
        }

        var updatedQuestions = questions
        var updatedQuestion = updatedQuestions[questionIndex]
        guard let answerIndex = updatedQuestion.answers.firstIndex(where: { $0.id == answerId }) else {
            return nil
        }

        updateQuestion(&updatedQuestion, answerIndex)
        updatedQuestions[questionIndex] = updatedQuestion
        return updatedQuestions
    }
}

// MARK: - Notifications

private extension QuestionsFeedViewModel {

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

        NotificationCenter.default
            .publisher(for: .bestAnswerChanged)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handleBestAnswerChangedNotification(notification)
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

    func handleBestAnswerChangedNotification(_ notification: Notification) {
        guard let questionId = notification.userInfo?[BestAnswerNotification.questionIdKey] as? Int,
              let answerId = notification.userInfo?[BestAnswerNotification.answerIdKey] as? Int,
              let isBest = notification.userInfo?[BestAnswerNotification.isBestKey] as? Bool
        else {
            return
        }

        applyBestAnswer(questionId: questionId, answerId: answerId, isBest: isBest)
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

    func notifyAnswerLikeChanged(answerId: Int, filter: FeedFilter) {
        guard
            let storage = feedStorageByFilter[filter],
            let answer = storage.questions.lazy.flatMap(\.answers).first(where: { $0.id == answerId })
        else {
            return
        }

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

private extension QuestionsFeedViewModel {

    func showToast(_ message: ToastMessage) {
        toast = message.item
    }

    func showToastIfNeeded(_ message: ToastMessage, for filter: FeedFilter) {
        guard selectedFilter == filter else { return }
        showToast(message)
    }
}
