import Foundation

struct AnswerActionResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case compCode = "CompCode"
    }

    let compCode: Int
}
