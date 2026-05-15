import Foundation

public struct Question: Identifiable, Hashable {
    
    public let id: Int
    public let publishDate: String
    public let isOwnedByCurrentUser: Bool
    public let isAnonymous: Bool
    public let authorId: Int
    public let authorAvatarData: Data?
    public let authorNick: String
    public let recipient: UserProfile?
    public let text: String
    public let audio: Audio?
    public var answersCount: Int
    public var answers: [Answer]
    
    public init(
        id: Int,
        publishDate: String,
        isOwnedByCurrentUser: Bool,
        isAnonymous: Bool,
        authorId: Int,
        authorAvatarData: Data?,
        authorNick: String,
        recipient: UserProfile?,
        text: String,
        audio: Audio?,
        answersCount: Int,
        answers: [Answer]
    ) {
        self.id = id
        self.publishDate = publishDate
        self.isOwnedByCurrentUser = isOwnedByCurrentUser
        self.isAnonymous = isAnonymous
        self.authorId = authorId
        self.authorAvatarData = authorAvatarData
        self.authorNick = authorNick
        self.recipient = recipient
        self.text = text
        self.audio = audio
        self.answersCount = answersCount
        self.answers = answers
    }
}
