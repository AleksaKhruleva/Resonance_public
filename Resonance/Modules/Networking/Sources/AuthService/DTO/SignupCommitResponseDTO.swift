import Foundation
import Core

struct SignupCommitResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case user = "UserRecord"
        case accessToken = "JwtAccess"
        case refreshToken = "JwtRefresh"
        case compCode = "CompCode"
    }

    let user: UserDTO
    let accessToken: String?
    let refreshToken: String?
    let compCode: Int

    func toDomain(accessToken: String, refreshToken: String) -> SignupCommitResponse {
        SignupCommitResponse(
            user: user.toDomain(),
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}
