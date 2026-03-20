import Foundation

struct UserSubscribeResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case compCode = "CompCode"
    }

    let compCode: Int
}
