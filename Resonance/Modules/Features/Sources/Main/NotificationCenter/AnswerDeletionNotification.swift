import Foundation

extension Notification.Name {
    static let answerPublished = Notification.Name("answerPublished")
    static let answerDeleted = Notification.Name("answerDeleted")
    static let answerLikeChanged = Notification.Name("answerLikeChanged")
}

enum AnswerPublishedNotification {
    static let questionIdKey = "questionId"
}

enum AnswerDeletionNotification {
    static let answerIdKey = "answerId"
}

enum AnswerLikeNotification {
    static let answerIdKey = "answerId"
    static let isLikedKey = "isLiked"
    static let likesCountKey = "likesCount"
}
