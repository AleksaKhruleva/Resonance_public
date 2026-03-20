import SwiftUI
import Core
import Networking

@MainActor
@Observable
final class ProfileSubscriptionsListViewModel {

    // MARK: - Internal Types

    enum Intent {
        case loadFeed
        case loadNextBatchIfNeeded(userId: Int)
        case openUserProfile(userNick: String)
        case dismissToast
    }

    enum State: Equatable {
        case loadingFeed
        case loadingNextBatch
        case content
        case empty
        case error(String?)
    }

    // MARK: - Properties

    private(set) var state: State = .empty
    private(set) var toast: ToastItem?
    private(set) var subscriptions: [UserProfile] = []

    private var hasMoreSubscriptions = true
    private var latestUserId = maxUserId
    private var lastFeedLoadedAt: Date?

    private let userNick: String
    private let userService: UserService
    private let onUserTap: ((String) -> Void)?

    private static let batchSize = 15
    private static let maxUserId = 999999999
    private static let feedRefreshInterval: TimeInterval = 2 * 60

    private var isLoading: Bool {
        state == .loadingFeed || state == .loadingNextBatch
    }

    private var shouldUpdateData: Bool {
        guard let lastFeedLoadedAt else { return true }
        return Date().timeIntervalSince(lastFeedLoadedAt) > Self.feedRefreshInterval
    }

    // MARK: - Internal Init

    init(
        userNick: String,
        userService: UserService = UserService(),
        onUserTap: ((String) -> Void)?
    ) {
        self.userNick = userNick
        self.userService = userService
        self.onUserTap = onUserTap
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .loadFeed:
            Task { await loadFeed() }
        case .loadNextBatchIfNeeded(let userId):
            guard userId == latestUserId else { return }
            Task { await loadNextBatch() }
        case .openUserProfile(let userNick):
            guard userNick != self.userNick else { return }
            onUserTap?(userNick)
        case .dismissToast:
            toast = nil
        }
    }

    // MARK: - Private Methods

    private func loadFeed() async {
        guard !isLoading, shouldUpdateData else { return }

        state = .loadingFeed

        let result = await userService.getUserSubscriptions(
            userNick: userNick,
            latestUserId: Self.maxUserId,
            batchSize: Self.batchSize
        )

        switch result {
        case .success(let loadedSubscriptions):
            subscriptions = loadedSubscriptions
            latestUserId = subscriptions.map(\.id).min() ?? Self.maxUserId
            hasMoreSubscriptions = subscriptions.count == Self.batchSize
            lastFeedLoadedAt = Date()
            state = subscriptions.isEmpty ? .empty : .content
        case .failure(let error):
            state = .error(error.localizedDescription)
        }
    }

    private func loadNextBatch() async {
        guard state == .content, hasMoreSubscriptions else { return }

        state = .loadingNextBatch

        let result = await userService.getUserSubscriptions(
            userNick: userNick,
            latestUserId: latestUserId,
            batchSize: Self.batchSize
        )

        switch result {
        case .success(let loadedSubscriptions):
            subscriptions.append(contentsOf: loadedSubscriptions)
            latestUserId = loadedSubscriptions.map(\.id).min() ?? latestUserId
            hasMoreSubscriptions = loadedSubscriptions.count == Self.batchSize
            state = .content
        case .failure:
            state = .content
            showToast(.nextBatchLoadFailed)
        }
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }
}
