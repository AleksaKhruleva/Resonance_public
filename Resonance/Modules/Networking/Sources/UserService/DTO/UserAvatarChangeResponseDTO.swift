import Foundation

struct UserAvatarChangeResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case compCode = "CompCode"
    }

    let compCode: Int
}
