import Foundation

public struct UserProfile: Identifiable, Hashable {
    
    public let id: Int
    public let email: String
    public let nick: String
    public let avatarData: Data?
    public let isSubscribedByCurrentUser: Bool
    public let postsCount: Int
    public var subscribersCount: Int
    public let subscriptionsCount: Int
    
    public init(
        id: Int,
        email: String,
        nick: String,
        avatarData: Data?,
        isSubscribedByCurrentUser: Bool,
        postsCount: Int,
        subscribersCount: Int,
        subscriptionsCount: Int
    ) {
        self.id = id
        self.email = email
        self.nick = nick
        self.avatarData = avatarData
        self.isSubscribedByCurrentUser = isSubscribedByCurrentUser
        self.postsCount = postsCount
        self.subscribersCount = subscribersCount
        self.subscriptionsCount = subscriptionsCount
    }
}
