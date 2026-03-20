import Foundation

public struct Post: Identifiable, Hashable {

    public let id: Int
    public let publishDate: String
    public let isOwnedByCurrentUser: Bool
    public let authorId: Int
    public let authorAvatarData: Data?
    public let authorNick: String
    public let imageData: Data?
    public let audio: Audio?
    public var likesCount: Int
    public var isLiked: Bool

    public init(
        id: Int,
        publishDate: String,
        isOwnedByCurrentUser: Bool,
        authorId: Int,
        authorAvatarData: Data?,
        authorNick: String,
        imageData: Data?,
        audio: Audio?,
        likesCount: Int,
        isLiked: Bool
    ) {
        self.id = id
        self.publishDate = publishDate
        self.isOwnedByCurrentUser = isOwnedByCurrentUser
        self.authorId = authorId
        self.authorAvatarData = authorAvatarData
        self.authorNick = authorNick
        self.imageData = imageData
        self.audio = audio
        self.likesCount = likesCount
        self.isLiked = isLiked
    }
}
