import Foundation

extension Notification.Name {
    static let profilePostDeleted = Notification.Name("profilePostDeleted")
    static let postLikeChanged = Notification.Name("postLikeChanged")
}

enum ProfilePostDeletionNotification {
    static let authorNickKey = "authorNick"
}

enum PostLikeNotification {
    static let postIdKey = "postId"
    static let isLikedKey = "isLiked"
    static let likesCountKey = "likesCount"
}
