import Foundation

struct QuestionDeleteRequestDTO: Encodable {

    enum CodingKeys: String, CodingKey {
        case questionRecord = "QuestionRecord"
    }

    let questionRecord: QuestionDeleteRecordDTO
}

struct QuestionDeleteRecordDTO: Encodable {

    enum CodingKeys: String, CodingKey {
        case questionId = "QuestionId"
        case authorId = "AuthorId"
    }

    let questionId: Int
    let authorId: Int
}
