import Foundation

extension Notification.Name {
    static let questionDeleted = Notification.Name("questionDeleted")
}

enum QuestionDeletionNotification {
    static let questionIdKey = "questionId"
    static let authorNickKey = "authorNick"
}
