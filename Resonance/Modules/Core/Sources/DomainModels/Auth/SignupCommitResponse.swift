import Foundation

public struct SignupCommitResponse {
    
    public let user: UserProfile
    public let accessToken: String
    public let refreshToken: String

    public init(
        user: UserProfile,
        accessToken: String,
        refreshToken: String
    ) {
        self.user = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}
