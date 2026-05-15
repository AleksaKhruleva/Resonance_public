import Foundation

public struct Device: Identifiable, Hashable {

    public let id: Int
    public let userId: Int
    public let token: String

    public init(
        id: Int,
        userId: Int,
        token: String
    ) {
        self.id = id
        self.userId = userId
        self.token = token
    }
}
