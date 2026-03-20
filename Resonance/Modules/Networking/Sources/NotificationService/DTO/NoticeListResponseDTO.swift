import Foundation

struct NoticeListResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case notices = "Notices"
        case compCode = "CompCode"
    }

    let notices: [NoticeDTO]
    let compCode: Int
}
