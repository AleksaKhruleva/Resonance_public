import Foundation

public struct CurrentUserInfo: Hashable {

    public let id: Int
    public let nick: String
    public let email: String
    public let deviceId: Int?
    public let deviceToken: String?

    public init(
        id: Int,
        nick: String,
        email: String,
        deviceId: Int?,
        deviceToken: String?
    ) {
        self.id = id
        self.nick = nick
        self.email = email
        self.deviceId = deviceId
        self.deviceToken = deviceToken
    }
}
