import SwiftUI
import Core
import Networking

@MainActor
@Observable
final class PostDetailedViewModel {

    enum Intent {
        case requestPostDeletion
        case cancelPostDeletion
        case confirmPostDeletion
        case toggleLike
        case postLikeChanged(postId: Int, isLiked: Bool, likesCount: Int)
        case dismissToast
    }

    enum State: Equatable {
        case content
        case deleting
    }

    private(set) var state: State = .content
    private(set) var toast: ToastItem?
    private(set) var isDeleteConfirmationPresented = false
    private(set) var shouldDismiss = false
    private(set) var post: Post
    private(set) var isLikeLoading = false

    private let postService: PostService

    init(
        post: Post,
        postService: PostService = PostService()
    ) {
        self.post = post
        self.postService = postService
    }

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
        case .postLikeChanged(let postId, let isLiked, let likesCount):
            applyPostLikeChanged(postId: postId, isLiked: isLiked, likesCount: likesCount)
        case .dismissToast:
            toast = nil
        }
    }

    private func confirmPostDeletion() async {
        guard state != .deleting else { return }

        isDeleteConfirmationPresented = false
        state = .deleting

        let result = await postService.deletePost(postId: post.id)

        switch result {
        case .success:
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
}
