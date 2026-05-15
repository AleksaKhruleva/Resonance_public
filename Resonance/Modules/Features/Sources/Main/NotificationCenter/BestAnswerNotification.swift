import Foundation

extension Notification.Name {
    static let bestAnswerChanged = Notification.Name("bestAnswerChanged")
}

enum BestAnswerNotification {
    static let questionIdKey = "questionId"
    static let answerIdKey = "answerId"
    static let isBestKey = "isBest"
}
