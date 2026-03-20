import Foundation

struct QuestionDeleteResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case compCode = "CompCode"
    }

    let compCode: Int
}
