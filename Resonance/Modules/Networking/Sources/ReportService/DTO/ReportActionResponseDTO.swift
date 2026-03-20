import Foundation

struct ReportActionResponseDTO: Decodable {
    enum CodingKeys: String, CodingKey {
        case compCode = "CompCode"
    }

    let compCode: Int
}
