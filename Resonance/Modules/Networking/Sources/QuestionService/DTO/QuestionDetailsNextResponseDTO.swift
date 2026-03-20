import Foundation

struct QuestionDetailsNextResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case answers = "Answers"
        case compCode = "CompCode"
    }

    let answers: [AnswerDTO]
    let compCode: Int?
}
