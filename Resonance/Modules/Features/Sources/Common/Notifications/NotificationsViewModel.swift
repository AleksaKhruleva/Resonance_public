import SwiftUI
import Core
import Networking

@MainActor
@Observable
final class NotificationsViewModel {

    // MARK: - Internal Types

    enum Intent {
        case loadFeed
        case refreshFeed
        case loadNextBatchIfNeeded(noticeId: Int)
        case openNotification(NotificationItem)
        case openActorProfile(NotificationItem)
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
    private(set) var notifications: [NotificationItem] = []

    private var hasMoreNotifications = true
    private var latestNoticeId = maxNoticeId
    private var lastFeedLoadedAt: Date?

    private let notificationService: NotificationService
    private let onUserTap: ((String) -> Void)?
    private let onQuestionTap: ((Int) -> Void)?
    private let onAnswerTap: ((Int, Int) -> Void)?

    private static let batchSize = 15
    private static let maxNoticeId = 999999999
    private static let feedRefreshInterval: TimeInterval = 2 * 60

    private var isLoading: Bool {
        state == .loadingFeed || state == .loadingNextBatch || state == .refreshingFeed
    }

    private var shouldUpdateData: Bool {
        guard let lastFeedLoadedAt else { return true }
        return Date().timeIntervalSince(lastFeedLoadedAt) > Self.feedRefreshInterval
    }

    // MARK: - Internal Init

    init(
        notificationService: NotificationService = NotificationService(),
        onUserTap: ((String) -> Void)?,
        onQuestionTap: ((Int) -> Void)?,
        onAnswerTap: ((Int, Int) -> Void)?
    ) {
        self.notificationService = notificationService
        self.onUserTap = onUserTap
        self.onQuestionTap = onQuestionTap
        self.onAnswerTap = onAnswerTap
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .loadFeed:
            Task { await loadFeed() }
        case .refreshFeed:
            Task { await loadFeed(forcedUpdate: true) }
        case .loadNextBatchIfNeeded(let noticeId):
            guard noticeId == latestNoticeId else { return }
            Task { await loadNextBatch() }
        case .openNotification(let item):
            openNotification(item)
        case .openActorProfile(let item):
            guard let actor = item.actor, actor.id != 0 else { return }
            onUserTap?(actor.nick)
        case .dismissToast:
            toast = nil
        }
    }

    // MARK: - Private Methods

    private func loadFeed(forcedUpdate: Bool = false) async {
        guard !isLoading else { return }
        guard shouldUpdateData || forcedUpdate else { return }

        state = notifications.isEmpty ? .loadingFeed : .refreshingFeed

        let result = await notificationService.getNotices(
            noticeId: Self.maxNoticeId,
            batchSize: Self.batchSize
        )

        switch result {
        case .success(let loadedNotices):
            notifications = loadedNotices.compactMap { NotificationItem(notice: $0) }
            latestNoticeId = loadedNotices.map(\.id).min() ?? Self.maxNoticeId
            hasMoreNotifications = loadedNotices.count == Self.batchSize
            lastFeedLoadedAt = Date()
            state = notifications.isEmpty ? .empty : .content
        case .failure(let error):
            if notifications.isEmpty {
                state = .error(error.localizedDescription)
            } else {
                state = .content
                showToast(.refreshFailed)
            }
        }
    }

    private func loadNextBatch() async {
        guard state == .content, hasMoreNotifications else { return }

        let noticeId = latestNoticeId
        state = .loadingNextBatch

        let result = await notificationService.getNotices(
            noticeId: noticeId,
            batchSize: Self.batchSize
        )

        switch result {
        case .success(let loadedNotices):
            notifications.append(contentsOf: loadedNotices.compactMap { NotificationItem(notice: $0) })
            latestNoticeId = loadedNotices.map(\.id).min() ?? noticeId
            hasMoreNotifications = loadedNotices.count == Self.batchSize
            state = notifications.isEmpty ? .empty : .content
        case .failure:
            state = .content
            showToast(.nextBatchLoadFailed)
        }
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }

    private func openNotification(_ item: NotificationItem) {
        guard let target = item.target else { return }

        switch target {
        case .profile(let userNick):
            onUserTap?(userNick)
        case .question(let questionId):
            onQuestionTap?(questionId)
        case .answer(let questionId, let answerId):
            onAnswerTap?(questionId, answerId)
        }
    }
}
