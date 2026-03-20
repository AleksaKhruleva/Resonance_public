import Foundation

struct PostDeleteRequestDTO: Encodable {

    enum CodingKeys: String, CodingKey {
        case postRecord = "PostRecord"
    }

    let postRecord: PostDeleteRecordDTO
}

struct PostDeleteRecordDTO: Encodable {

    enum CodingKeys: String, CodingKey {
        case postId = "PostId"
    }

    let postId: Int
}
