import Foundation

struct LikeDTO: Codable {

    enum CodingKeys: String, CodingKey {
        case likesCount = "LikeQ"
        case compCode = "CompCode"
    }

    let likesCount: Int?
    let compCode: Int
}
