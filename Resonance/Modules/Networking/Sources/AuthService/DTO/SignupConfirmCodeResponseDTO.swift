import Foundation
import Core

struct SignupConfirmCodeResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case accessToken = "JwtAccess"
        case refreshToken = "JwtRefresh"
        case compCode = "CompCode"
    }

    let accessToken: String?
    let refreshToken: String?
    let compCode: Int

    func toDomain() -> SignupConfirmCodeResponse {
        SignupConfirmCodeResponse(
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}
