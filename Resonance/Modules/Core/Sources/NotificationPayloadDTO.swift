import Foundation

public enum NotificationType: String, Decodable {
    case newFollower = "follow_yes"
    case newQuestion = "question_create"
    case newAnswer = "answer_create"
}

public struct NotificationPayloadDTO: Decodable {

    public enum CodingKeys: String, CodingKey {
        case type = "Type"
        case initiatorNick = "UserNick1"
        case questionId = "QuestionId"
        case answerId = "AnswerId"
    }

    public let type: NotificationType
    public let initiatorNick: String?
    public let questionId: Int
    public let answerId: Int
}
