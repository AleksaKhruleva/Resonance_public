import Foundation
import Core

struct NotificationDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case id = "NoticeId"
        case publishDate = "SysDt"
        case initiatorNick = "InitiatorNick"
        case initiatorAvatar = "InitiatorAva"
        case payload = "Json"
    }

    let id: Int
    let publishDate: String
    let initiatorNick: String?
    let initiatorAvatar: MediaDTO?
    let payload: String

    func toDomain(with payload: NotificationPayloadDTO) -> ResonanceNotification {
        let initiatorAvatarData = initiatorAvatar.flatMap { Data(base64Encoded: $0.base64String) }

        return ResonanceNotification(
            id: id,
            publishDate: publishDate,
            type: payload.type,
            initiatorNick: initiatorNick,
            initiatorAvatarData: initiatorAvatarData,
            questionId: payload.questionId,
            asnwerId: payload.answerId
        )
    }
}
