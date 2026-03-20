import Foundation
import Core

struct NoticeDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case id = "NoticeId"
        case publishDate = "SysDt"
        case userId = "UserId"
        case json = "Json"
        case initiatorNick = "InitiatorNick"
        case initiatorAvatar = "InitiatorAva"
    }

    let id: Int
    let publishDate: String
    let userId: Int
    let json: String
    let initiatorNick: String?
    let initiatorAvatar: MediaDTO?

    func toDomain() -> Notice {
        Notice(
            id: id,
            publishDate: publishDate,
            userId: userId,
            initiatorNick: initiatorNick ?? "Пользователь #\(userId)",
            initiatorAvatarData: initiatorAvatar.flatMap { Data(base64Encoded: $0.base64String) },
            payload: payload
        )
    }

    private var payload: NoticePayload? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(NoticePayloadDTO.self, from: data).toDomain()
    }
}

private struct NoticePayloadDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case userId1 = "UserId1"
        case userId2 = "UserId2"
        case questionId = "QuestionId"
        case answerId = "AnswerId"
    }

    let type: String
    let userId1: Int?
    let userId2: Int?
    let questionId: Int?
    let answerId: Int?

    func toDomain() -> NoticePayload {
        switch type {
        case "follow_yes":
            guard let userId1, let userId2 else { return .unsupported(type: type) }
            return .newFollower(actorUserId: userId1, recipientUserId: userId2)
        case "question_create":
            guard let userId1, let userId2, let questionId else { return .unsupported(type: type) }
            return .newDirectQuestion(
                actorUserId: userId1,
                recipientUserId: userId2,
                questionId: questionId
            )
        case "answer_create":
            guard let userId1, let userId2, let questionId, let answerId else { return .unsupported(type: type) }
            return .newAnswer(
                actorUserId: userId1,
                recipientUserId: userId2,
                questionId: questionId,
                answerId: answerId
            )
        default:
            return .unsupported(type: type)
        }
    }
}
