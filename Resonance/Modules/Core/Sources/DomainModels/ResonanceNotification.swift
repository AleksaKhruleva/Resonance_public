import Foundation

public struct ResonanceNotification: Identifiable, Hashable {

    public let id: Int
    public let publishDate: String
    public let type: NotificationType
    public let initiatorNick: String?
    public let initiatorAvatarData: Data?
    public let questionId: Int
    public let asnwerId: Int

    public init(
        id: Int,
        publishDate: String,
        type: NotificationType,
        initiatorNick: String?,
        initiatorAvatarData: Data?,
        questionId: Int,
        asnwerId: Int
    ) {
        self.id = id
        self.publishDate = publishDate
        self.type = type
        self.initiatorNick = initiatorNick
        self.initiatorAvatarData = initiatorAvatarData
        self.questionId = questionId
        self.asnwerId = asnwerId
    }
}
