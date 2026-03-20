import Foundation

struct CreatePostResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case compCode = "CompCode"
    }

    let compCode: Int
}
