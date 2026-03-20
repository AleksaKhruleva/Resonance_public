import Foundation
import Core

struct QuestionDTO: Codable {

    enum CodingKeys: String, CodingKey {
        case id = "QuestionId"
        case publishDate = "SysDt"
        case isAnonymous = "Anonymous"
        case authorId = "AuthorId"
        case authorAvatar = "Ava"
        case authorNick = "Nick"
        case recipientId = "RecipientId"
        case recipient = "RecipientUser"
        case text = "QuestionText"
        case media = "Media"
        case answersCount = "AnswerQ"
        case answers = "Answers"
        case compCode = "CompCode"
    }

    let id: Int
    let publishDate: String
    let isAnonymous: String
    let authorId: Int
    let authorAvatar: MediaDTO
    let authorNick: String
    let recipientId: Int
    let recipient: UserDTO?
    let text: String
    let media: MediaDTO
    let answersCount: Int
    let answers: [AnswerDTO]
    let compCode: Int

    func toDomain(with currentUserId: Int?) -> Question {
        var recipient: UserProfile?
        if recipientId != 0 {
            recipient = self.recipient.map { $0.toDomain() }
        }

        let json = AudioMediaToJsonConverter(media.base64String)
        var audio: Audio?
        if let data = json.audioData {
            audio = Audio(data: data, durationSeconds: json.durationSeconds)
        }

        return Question(
            id: id,
            publishDate: publishDate,
            isOwnedByCurrentUser: authorId == currentUserId,
            isAnonymous: isAnonymous == "Y",
            authorId: authorId,
            authorAvatarData: Data(base64Encoded: authorAvatar.base64String),
            authorNick: authorNick,
            recipient: recipient,
            text: text,
            audio: audio,
            answersCount: answersCount,
            answers: answers.map { $0.toDomain(with: currentUserId) }
        )
    }
}
