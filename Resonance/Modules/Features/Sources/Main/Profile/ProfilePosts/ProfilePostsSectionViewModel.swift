import SwiftUI
import Core
import Networking
import Combine

@MainActor
@Observable
final class ProfilePostsSectionViewModel {

    // MARK: - Internal Types

    enum Intent {
        case loadFeed
        case refreshFeed
        case invalidateFeed
        case userNickChanged(String)
        case loadNextBatchIfNeeded(postId: Int)
        case openPostDetails(post: Post)
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
    private(set) var posts: [Post] = []

    private var hasMorePosts = true
    private var latestPostId = maxPostId
    private var lastFeedLoadedAt: Date?
    private var postLikeChangedCancellable: AnyCancellable?

    private var userNick: String
    private let postService: PostService
    private let onPostTap: ((Post) -> Void)?

    private static let feedMode = PostsFeedMode.nick
    private static let batchSize = 12
    private static let maxPostId = 999999999
    private static let feedRefreshInterval: TimeInterval = 2 * 60

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
        postService: PostService = PostService(),
        onPostTap: ((Post) -> Void)?
    ) {
        self.userNick = userNick
        self.postService = postService
        self.onPostTap = onPostTap
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
        case .loadNextBatchIfNeeded(let postId):
            guard postId == latestPostId else { return }
            Task { await loadNextBatch() }
        case .openPostDetails(let post):
            onPostTap?(post)
        case .dismissToast:
            toast = nil
        }
    }

    // MARK: - Private Methods

    private func loadFeed(force: Bool = false) async {
        guard !isLoading, force || shouldUpdateData else { return }

        state = isRefreshing ? .refreshingFeed : .loadingFeed

        let result = await postService.getPostsFeed(
            for: userNick,
            latestPostId: Self.maxPostId,
            batchSize: Self.batchSize,
            mode: Self.feedMode
        )

        switch result {
        case .success(let loadedPosts):
            posts = loadedPosts
            latestPostId = posts.map(\.id).min() ?? Self.maxPostId
            hasMorePosts = posts.count == Self.batchSize
            lastFeedLoadedAt = Date()
            state = posts.isEmpty ? .empty : .content
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
        guard state == .content, hasMorePosts else { return }

        state = .loadingNextBatch

        let result = await postService.getPostsFeed(
            for: userNick,
            latestPostId: latestPostId,
            batchSize: Self.batchSize,
            mode: Self.feedMode
        )

        switch result {
        case .success(let loadedPosts):
            posts.append(contentsOf: loadedPosts)
            latestPostId = loadedPosts.map(\.id).min() ?? Self.maxPostId
            hasMorePosts = loadedPosts.count == Self.batchSize
            lastFeedLoadedAt = Date()
            state = .content
        case .failure:
            state = .content
            showToast(.nextBatchLoadFailed)
        }
    }

    private func observeNotifications() {
        postLikeChangedCancellable = NotificationCenter.default
            .publisher(for: .postLikeChanged)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handlePostLikeChangedNotification(notification)
                }
            }
    }

    private func handlePostLikeChangedNotification(_ notification: Notification) {
        guard let postId = notification.userInfo?[PostLikeNotification.postIdKey] as? Int,
              let isLiked = notification.userInfo?[PostLikeNotification.isLikedKey] as? Bool,
              let likesCount = notification.userInfo?[PostLikeNotification.likesCountKey] as? Int
        else {
            return
        }

        applyPostLikeChanged(postId: postId, isLiked: isLiked, likesCount: likesCount)
    }

    private func applyPostLikeChanged(postId: Int, isLiked: Bool, likesCount: Int) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        posts[index].isLiked = isLiked
        posts[index].likesCount = likesCount
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }
}
