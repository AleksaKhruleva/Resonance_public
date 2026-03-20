import Foundation

public enum NoticePayload: Hashable {
    case newFollower(actorUserId: Int, recipientUserId: Int)
    case newDirectQuestion(actorUserId: Int, recipientUserId: Int, questionId: Int)
    case newAnswer(actorUserId: Int, recipientUserId: Int, questionId: Int, answerId: Int)
    case unsupported(type: String)
}

public struct Notice: Identifiable, Hashable {

    public let id: Int
    public let publishDate: String
    public let userId: Int
    public let initiatorNick: String
    public let initiatorAvatarData: Data?
    public let payload: NoticePayload?

    public init(
        id: Int,
        publishDate: String,
        userId: Int,
        initiatorNick: String,
        initiatorAvatarData: Data?,
        payload: NoticePayload?
    ) {
        self.id = id
        self.publishDate = publishDate
        self.userId = userId
        self.initiatorNick = initiatorNick
        self.initiatorAvatarData = initiatorAvatarData
        self.payload = payload
    }
}
