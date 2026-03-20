import Foundation

public struct SigninResponse: Decodable {
    public let CompCode: Int
    public let ReasonCodeS: String
    public let JwtAccess: String?
}

public struct SignupResponse: Decodable {
    public let CompCode: Int
    public let ReasonCodeS: String
    public let JwtAccess: String?
}
