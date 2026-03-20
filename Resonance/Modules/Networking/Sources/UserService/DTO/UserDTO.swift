import Foundation
import Core

struct UserDTO: Codable {

    enum CodingKeys: String, CodingKey {
        case id = "UserId"
        case email = "Email"
        case nick = "Nick"
        case avatar = "Ava"
        case isSubscribedByCurrentUser = "Followed"
        case postsCount = "PostQ"
        case subscribersCount = "FollowerQ"
        case subscriptionsCount = "BloggerQ"
    }

    let id: Int
    let email: String
    let nick: String
    let avatar: MediaDTO
    let isSubscribedByCurrentUser: String
    let postsCount: Int
    let subscribersCount: Int
    let subscriptionsCount: Int

    func toDomain() -> UserProfile {
        UserProfile(
            id: id,
            email: email,
            nick: nick,
            avatarData: Data(base64Encoded: avatar.base64String),
            isSubscribedByCurrentUser: isSubscribedByCurrentUser == "Y",
            postsCount: postsCount,
            subscribersCount: subscribersCount,
            subscriptionsCount: subscriptionsCount
        )
    }
}
