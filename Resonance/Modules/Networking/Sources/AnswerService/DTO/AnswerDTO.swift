import Foundation
import Core

struct AnswerDTO: Codable {

    enum CodingKeys: String, CodingKey {
        case id = "AnswerId"
        case publishDate = "SysDt"
        case isBest = "Best"
        case authorId = "AuthorId"
        case authorAvatar = "Ava"
        case authorNick = "Nick"
        case text = "AnswerText"
        case media = "Media"
        case likesCount = "LikeQ"
        case isLiked = "Liked"
    }

    let id: Int
    let publishDate: String
    let isBest: String
    let authorId: Int
    let authorAvatar: MediaDTO
    let authorNick: String
    let text: String
    let media: MediaDTO
    let likesCount: Int
    let isLiked: String

    func toDomain(with currentUserId: Int?) -> Answer {
        let json = AudioMediaToJsonConverter(media.base64String)

        var audio: Audio?
        if let data = json.audioData {
            audio = Audio(data: data, durationSeconds: json.durationSeconds)
        }

        return Answer(
            id: id,
            publishDate: publishDate,
            isOwnedByCurrentUser: authorId == currentUserId,
            isBest: isBest == "Y",
            authorId: authorId,
            authorAvatarData: Data(base64Encoded: authorAvatar.base64String),
            authorNick: authorNick,
            text: text,
            audio: audio,
            likesCount: likesCount,
            isLiked: isLiked == "Y"
        )
    }
}
