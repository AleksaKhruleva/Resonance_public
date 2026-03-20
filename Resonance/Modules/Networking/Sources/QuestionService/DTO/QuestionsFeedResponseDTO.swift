import Foundation

struct QuestionsFeedResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case questions = "Questions"
        case compCode = "CompCode"
    }

    let questions: [QuestionDTO]
    let compCode: Int
}
