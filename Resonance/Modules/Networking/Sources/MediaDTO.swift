import Foundation

struct MediaDTO: Codable {

    enum CodingKeys: String, CodingKey {
        case base64String = "Media"
    }

    let base64String: String
}
