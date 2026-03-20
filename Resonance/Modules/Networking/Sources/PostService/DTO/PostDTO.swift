import Foundation
import Core

struct PostDTO: Codable {

    enum CodingKeys: String, CodingKey {
        case id = "PostId"
        case publishDate = "SysDt"
        case authorId = "UserId"
        case authorAvatar = "Ava"
        case authorNick = "Nick"
        case media = "Media"
        case likesCount = "LikeQ"
        case isLiked = "Liked"
    }

    let id: Int
    let publishDate: String
    let authorId: Int
    let authorAvatar: MediaDTO
    let authorNick: String
    let media: MediaDTO
    let likesCount: Int
    let isLiked: String

    func toDomain(with currentUserId: Int?) -> Post {
        let json = PostMediaToJsonConverter(media.base64String)

        var audio: Audio?
        if let data = json.audioData {
            audio = Audio(data: data, durationSeconds: json.durationSeconds)
        }

        return Post(
            id: id,
            publishDate: publishDate,
            isOwnedByCurrentUser: authorId == currentUserId,
            authorId: authorId,
            authorAvatarData: Data(base64Encoded: authorAvatar.base64String),
            authorNick: authorNick,
            imageData: json.imageData,
            audio: audio,
            likesCount: likesCount,
            isLiked: isLiked == "Y"
        )
    }
}
