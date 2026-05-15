import Foundation

struct SigninWithEmailResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case accessToken = "JwtAccess"
        case compCode = "CompCode"
    }

    let accessToken: String?
    let compCode: Int
}
