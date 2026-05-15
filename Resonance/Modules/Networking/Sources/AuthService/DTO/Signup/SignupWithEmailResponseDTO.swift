import Foundation
import Core

struct SignupWithEmailResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case accessToken = "JwtAccess"
        case compCode = "CompCode"
    }

    let accessToken: String?
    let compCode: Int

    func toDomain(accessToken: String) -> SignupWithEmailResponse {
        SignupWithEmailResponse(accessToken: accessToken)
    }
}
