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
        case loadNextBatchIfNeeded(notificationId: Int)
        case openUserProfile(userNick: String?)
        case openNotification(notification: ResonanceNotification)
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

    struct NotificationSection: Identifiable {
        let period: NotificationPeriod
        let notifications: [ResonanceNotification]

        var id: NotificationPeriod {
            period
        }
    }

    enum NotificationPeriod: String, Identifiable, CaseIterable {
        case today
        case thisWeek
        case earlier

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .today:
                return "Сегодня"
            case .thisWeek:
                return "На этой неделе"
            case .earlier:
                return "Ранее"
            }
        }
    }

    // MARK: - Properties

    private(set) var toast: ToastItem?
    private(set) var state: State = .empty
    private(set) var notifications: [ResonanceNotification] = []

    var notificationSections: [NotificationSection] {
        let grouped = Dictionary(grouping: notifications) { notification in
            period(for: notification)
        }

        return NotificationPeriod.allCases.compactMap { period in
            guard let notifications = grouped[period], !notifications.isEmpty else {
                return nil
            }
            return NotificationSection(
                period: period,
                notifications: notifications
            )
        }
    }

    private var hasMoreNotifications = true
    private var latestNotificationId = maxNotificationId
    private var lastFeedLoadedAt: Date?

    private let notificationService: NotificationService
    private let notificationsManager: NotificationsManager
    private let onUserTap: ((String) -> Void)?
    private let onQuestionTap: ((Int) -> Void)?
    private let onAnswerTap: ((Int, Int) -> Void)?

    private static let batchSize = 15
    private static let maxNotificationId = 999999999
    private static let feedRefreshInterval: TimeInterval = 2 * 60

    private var isLoading: Bool {
        state == .loadingFeed || state == .loadingNextBatch || state == .refreshingFeed
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
        notificationService: NotificationService = NotificationService(),
        notificationsManager: NotificationsManager,
        onUserTap: ((String) -> Void)?,
        onQuestionTap: ((Int) -> Void)?,
        onAnswerTap: ((Int, Int) -> Void)?
    ) {
        self.notificationService = notificationService
        self.notificationsManager = notificationsManager
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

        case .loadNextBatchIfNeeded(let notificationId):
            guard notificationId == latestNotificationId else { return }
            Task { await loadNextBatch() }

        case .openUserProfile(let userNick):
            guard let userNick else { return }
            onUserTap?(userNick)

        case .openNotification(let notification):
            handleNotificationTap(notification: notification)

        case .dismissToast:
            toast = nil
        }
    }

    // MARK: - Private Methods

    private func loadFeed(forcedUpdate: Bool = false) async {
        guard !isLoading, shouldUpdateData || forcedUpdate else { return }

        state = isRefreshing ? .refreshingFeed : .loadingFeed

        if isRefreshing {
            try? await Task.sleep(nanoseconds: 0_500_000_000)
        }

        let result = await notificationService.getNotificationsFeed(
            notificationId: Self.maxNotificationId,
            batchSize: Self.batchSize
        )

        switch result {
        case .success(let result):
            let loadedNotifications = result.0
            let newBadgeCount = result.1
            notifications = loadedNotifications
            latestNotificationId = notifications.map(\.id).min() ?? Self.maxNotificationId
            hasMoreNotifications = notifications.count == Self.batchSize
            lastFeedLoadedAt = Date()
            state = notifications.isEmpty ? .empty : .content
            notificationsManager.updateBadgeCount(with: newBadgeCount)
        case .failure(let error):
            if isRefreshing {
                state = .content
                showToast(.refreshFailed)
            } else {
                state = .error(error.localizedDescription)
            }
        }
    }

    private func loadNextBatch() async {
        guard state == .content, hasMoreNotifications else { return }

        state = .loadingNextBatch

        let result = await notificationService.getNotificationsFeed(
            notificationId: latestNotificationId,
            batchSize: Self.batchSize
        )

        switch result {
        case .success(let result):
            let loadedNotifications = result.0
            let newBadgeCount = result.1
            notifications.append(contentsOf: loadedNotifications)
            latestNotificationId = loadedNotifications.map(\.id).min() ?? Self.maxNotificationId
            hasMoreNotifications = loadedNotifications.count == Self.batchSize
            lastFeedLoadedAt = Date()
            state = .content
            notificationsManager.updateBadgeCount(with: newBadgeCount)
        case .failure:
            state = .content
            showToast(.nextBatchLoadFailed)
        }
    }

    private func handleNotificationTap(notification: ResonanceNotification) {
        switch notification.type {
        case .newFollower:
            guard let userNick = notification.initiatorNick else { return }
            onUserTap?(userNick)

        case .newQuestion:
            onQuestionTap?(notification.questionId)

        case .newAnswer:
            onAnswerTap?(notification.questionId, notification.asnwerId)
        }
    }

    private func period(for notification: ResonanceNotification) -> NotificationPeriod {
        guard let date = PublicationDateFormatter.date(from: notification.publishDate) else {
            return .earlier
        }

        let calendar = Calendar.autoupdatingCurrent
        let now = Date()

        if calendar.isDateInToday(date) {
            return .today
        }

        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return .thisWeek
        }

        return .earlier
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }
}
