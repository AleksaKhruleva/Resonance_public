import Foundation
import Core

struct SigninConfirmCodeResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case user = "UserRecord"
        case accessToken = "JwtAccess"
        case refreshToken = "JwtRefresh"
        case compCode = "CompCode"
    }

    let user: UserDTO?
    let accessToken: String?
    let refreshToken: String?
    let compCode: Int

    func toDomain(
        user: UserDTO,
        accessToken: String,
        refreshToken: String
    ) -> SigninConfirmCodeResponse {
        SigninConfirmCodeResponse(
            user: user.toDomain(),
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }
}
