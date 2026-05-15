import SwiftUI
import Core
import Networking
import Combine

@MainActor
@Observable
final class PostDetailedViewModel {

    // MARK: - Internal Types

    enum Intent {
        case requestPostDeletion
        case cancelPostDeletion
        case confirmPostDeletion
        case toggleLike
        case reportSent
        case dismissToast
    }

    enum State: Equatable {
        case content
        case deleting
    }

    // MARK: - Properties

    private(set) var toast: ToastItem?
    private(set) var state: State = .content
    private(set) var post: Post
    private(set) var isDeleteConfirmationPresented = false
    private(set) var shouldDismiss = false
    private(set) var isLikeLoading = false

    private var postLikeChangedCancellable: AnyCancellable?

    private let postService: PostService

    // MARK: - Internal Init

    init(
        post: Post,
        postService: PostService = PostService()
    ) {
        self.post = post
        self.postService = postService
        observeNotifications()
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .requestPostDeletion:
            guard post.isOwnedByCurrentUser else { return }
            isDeleteConfirmationPresented = true
        case .cancelPostDeletion:
            isDeleteConfirmationPresented = false
        case .confirmPostDeletion:
            Task { await confirmPostDeletion() }
        case .toggleLike:
            Task { await toggleLike() }
        case .reportSent:
            toast = ToastMessage.reportSent.item
        case .dismissToast:
            toast = nil
        }
    }

    // MARK: - Private Methods

    private func confirmPostDeletion() async {
        guard state != .deleting else { return }

        isDeleteConfirmationPresented = false
        state = .deleting

        let result = await postService.deletePost(postId: post.id)

        switch result {
        case .success:
            notifyPostDeleted()
            shouldDismiss = true
        case .failure:
            state = .content
            toast = ToastMessage.deletePostFailed.item
        }
    }

    private func toggleLike() async {
        guard !isLikeLoading else { return }

        isLikeLoading = true
        defer { isLikeLoading = false }

        let originalPost = post
        post.isLiked.toggle()
        post.likesCount = max(0, post.likesCount + (post.isLiked ? 1 : -1))

        let result = await postService.toggleLike(
            postId: post.id,
            isLiked: originalPost.isLiked
        )

        switch result {
        case .success(let updatedLikesCount):
            if let updatedLikesCount {
                post.likesCount = updatedLikesCount
            }
            notifyPostLikeChanged()
        case .failure:
            post = originalPost
            toast = ToastMessage.likeFailed.item
        }
    }

    private func applyPostLikeChanged(postId: Int, isLiked: Bool, likesCount: Int) {
        guard post.id == postId else { return }

        post.isLiked = isLiked
        post.likesCount = likesCount
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

    private func notifyPostDeleted() {
        NotificationCenter.default.post(
            name: .profilePostDeleted,
            object: nil,
            userInfo: [
                ProfilePostDeletionNotification.authorNickKey: post.authorNick
            ]
        )
    }

    private func notifyPostLikeChanged() {
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

    private func handlePostLikeChangedNotification(_ notification: Notification) {
        guard let postId = notification.userInfo?[PostLikeNotification.postIdKey] as? Int,
              let isLiked = notification.userInfo?[PostLikeNotification.isLikedKey] as? Bool,
              let likesCount = notification.userInfo?[PostLikeNotification.likesCountKey] as? Int
        else {
            return
        }

        applyPostLikeChanged(postId: postId, isLiked: isLiked, likesCount: likesCount)
    }
}
