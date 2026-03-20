import Foundation

struct PostsFeedResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case posts = "PostListRecords"
        case compCode = "CompCode"
    }

    let posts: [PostDTO]
    let compCode: Int
}
