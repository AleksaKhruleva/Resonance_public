import Foundation

public struct Answer: Identifiable, Hashable {

    public let id: Int
    public let publishDate: String
    public let isOwnedByCurrentUser: Bool
    public var isBest: Bool
    public let authorId: Int
    public let authorAvatarData: Data?
    public let authorNick: String
    public let text: String
    public let audio: Audio?
    public var likesCount: Int
    public var isLiked: Bool

    public init(
        id: Int,
        publishDate: String,
        isOwnedByCurrentUser: Bool,
        isBest: Bool,
        authorId: Int,
        authorAvatarData: Data?,
        authorNick: String,
        text: String,
        audio: Audio?,
        likesCount: Int,
        isLiked: Bool
    ) {
        self.id = id
        self.publishDate = publishDate
        self.isOwnedByCurrentUser = isOwnedByCurrentUser
        self.isBest = isBest
        self.authorId = authorId
        self.authorAvatarData = authorAvatarData
        self.authorNick = authorNick
        self.text = text
        self.audio = audio
        self.likesCount = likesCount
        self.isLiked = isLiked
    }
}
