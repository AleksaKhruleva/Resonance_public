import Foundation

public struct SignupWithEmailResponse {
    
    public let accessToken: String

    public init(accessToken: String) {
        self.accessToken = accessToken
    }
}
