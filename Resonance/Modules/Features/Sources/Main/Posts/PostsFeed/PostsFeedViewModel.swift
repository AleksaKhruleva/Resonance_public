import SwiftUI
import Networking
import Core
import Combine

@MainActor
@Observable
final class PostsFeedViewModel {

    // MARK: - Internal Types

    enum Intent {
        case loadFeed
        case refreshFeed
        case refreshFeedIfNeeded(trigger: Int)
        case loadNextBatchIfNeeded(postId: Int)
        case openAuthorProfile(authorNick: String)
        case openNotifications
        case toggleLike(postId: Int)
        case requestPostDeletion(postId: Int)
        case dismissPostDeletion
        case cancelPostDeletion
        case confirmPostDeletion
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
    private(set) var postPendingDeletion: Post?
    private(set) var isDeleteConfirmationPresented = false
    private(set) var posts: [Post] = []

    private var likingPostIds = Set<Int>()
    private var deletingPostIds = Set<Int>()
    private var hasMorePosts = true
    private var latestPostId = maxPostId
    private var lastFeedLoadedAt: Date?
    private var handledRefreshTrigger = 0
    private var postLikeChangedCancellable: AnyCancellable?

    private let currentUser: CurrentUserInfo
    private let onAuthorTap: ((String) -> Void)?
    private let onNotificationsTap: (() -> Void)?
    private let postService: PostService

    private static let feedMode = PostsFeedMode.followingOrMy
    private static let batchSize = 10
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
        currentUser: CurrentUserInfo,
        onAuthorTap: ((String) -> Void)?,
        onNotificationsTap: (() -> Void)? = nil,
        postService: PostService = PostService()
    ) {
        self.currentUser = currentUser
        self.onAuthorTap = onAuthorTap
        self.onNotificationsTap = onNotificationsTap
        self.postService = postService
        observeNotifications()
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .loadFeed:
            Task { await loadFeed() }
        case .refreshFeed:
            Task { await loadFeed(forcedUpdate: true) }
        case .refreshFeedIfNeeded(let trigger):
            refreshFeedIfNeeded(trigger: trigger)
        case .loadNextBatchIfNeeded(let postId):
            guard postId == latestPostId else { return }
            Task { await loadNextBatch() }
        case .openAuthorProfile(let authorNick):
            onAuthorTap?(authorNick)
        case .openNotifications:
            onNotificationsTap?()
        case .toggleLike(let postId):
            Task { await toggleLike(postId: postId) }
        case .requestPostDeletion(let postId):
            requestPostDeletion(postId: postId)
        case .dismissPostDeletion:
            isDeleteConfirmationPresented = false
        case .cancelPostDeletion:
            isDeleteConfirmationPresented = false
            postPendingDeletion = nil
        case .confirmPostDeletion:
            Task { await confirmPostDeletion() }
        case .dismissToast:
            toast = nil
        }
    }

    func isLikeLoading(postId: Int) -> Bool {
        likingPostIds.contains(postId)
    }

    func isPostDeleting(postId: Int) -> Bool {
        deletingPostIds.contains(postId)
    }

    // MARK: - Private Methods

    private func refreshFeedIfNeeded(trigger: Int) {
        guard trigger != handledRefreshTrigger else { return }
        handledRefreshTrigger = trigger
        Task { await loadFeed(forcedUpdate: true) }
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

    private func loadFeed(forcedUpdate: Bool = false) async {
        guard !isLoading, shouldUpdateData || forcedUpdate else { return }

        state = isRefreshing ? .refreshingFeed : .loadingFeed

        if isRefreshing {
            try? await Task.sleep(nanoseconds: 0_500_000_000)
        }

        let result = await postService.getPostsFeed(
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

    private func requestPostDeletion(postId: Int) {
        guard
            !isDeleteConfirmationPresented,
            !deletingPostIds.contains(postId),
            let post = posts.first(where: { $0.id == postId }),
            post.isOwnedByCurrentUser
        else {
            return
        }

        postPendingDeletion = post
        isDeleteConfirmationPresented = true
    }

    private func confirmPostDeletion() async {
        guard
            let post = postPendingDeletion,
            !deletingPostIds.contains(post.id)
        else {
            return
        }

        isDeleteConfirmationPresented = false
        postPendingDeletion = nil
        deletingPostIds.insert(post.id)
        defer { deletingPostIds.remove(post.id) }

        let result = await postService.deletePost(postId: post.id)

        switch result {
        case .success:
            posts.removeAll { $0.id == post.id }
            state = posts.isEmpty ? .empty : .content
            NotificationCenter.default.post(
                name: .profilePostDeleted,
                object: nil,
                userInfo: [
                    ProfilePostDeletionNotification.authorNickKey: post.authorNick
                ]
            )
        case .failure:
            showToast(.deletePostFailed)
        }
    }

    private func toggleLike(postId: Int) async {
        guard
            !likingPostIds.contains(postId),
            let index = posts.firstIndex(where: { $0.id == postId })
        else {
            return
        }

        likingPostIds.insert(postId)
        defer { likingPostIds.remove(postId) }

        let originalPost = posts[index]

        var updatedPosts = posts
        updatedPosts[index].isLiked.toggle()
        updatedPosts[index].likesCount = max(0, updatedPosts[index].likesCount + (updatedPosts[index].isLiked ? 1 : -1))
        posts = updatedPosts

        let result = await postService.toggleLike(
            postId: postId,
            isLiked: originalPost.isLiked
        )

        switch result {
        case .success(let updatedLikesCount):
            if let updatedLikesCount, let latestIndex = posts.firstIndex(where: { $0.id == postId }) {
                var latestPosts = posts
                latestPosts[latestIndex].likesCount = updatedLikesCount
                posts = latestPosts
            }
            notifyPostLikeChanged(postId: postId)
        case .failure:
            if let latestIndex = posts.firstIndex(where: { $0.id == postId }) {
                var latestPosts = posts
                latestPosts[latestIndex] = originalPost
                posts = latestPosts
            }
            showToast(.likeFailed)
        }
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }

    private func handlePostLikeChangedNotification(_ notification: Notification) {
        guard
            let postId = notification.userInfo?[PostLikeNotification.postIdKey] as? Int,
            let isLiked = notification.userInfo?[PostLikeNotification.isLikedKey] as? Bool,
            let likesCount = notification.userInfo?[PostLikeNotification.likesCountKey] as? Int
        else {
            return
        }

        applyPostLikeChanged(
            postId: postId,
            isLiked: isLiked,
            likesCount: likesCount
        )
    }

    private func applyPostLikeChanged(postId: Int, isLiked: Bool, likesCount: Int) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        posts[index].isLiked = isLiked
        posts[index].likesCount = likesCount
    }

    private func notifyPostLikeChanged(postId: Int) {
        guard let post = posts.first(where: { $0.id == postId }) else { return }

        NotificationCenter.default.post(
            name: .postLikeChanged,
            object: nil,
            userInfo: [
                PostLikeNotification.postIdKey: post.id,
                PostLikeNotification.isLikedKey: post.isLiked,
                PostLikeNotification.likesCountKey: post.likesCount
            ]
        )
    }
}
