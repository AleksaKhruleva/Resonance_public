import Foundation

public struct CurrentUser: Hashable {

    public let id: Int
    public let nick: String
    public let email: String

    public init?(
        id: Int,
        nick: String,
        email: String
    ) {
        guard
            let normalizedNick = nick.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        else {
            return nil
        }

        self.id = id
        self.nick = normalizedNick
        self.email = normalizedEmail
    }

    public init?(user: UserProfile) {
        self.init(
            id: user.id,
            nick: user.nick,
            email: user.email
        )
    }
}
