import Core
import Foundation

struct UserProfileResponseDTO: Codable {

    enum CodingKeys: String, CodingKey {
        case compCode = "CompCode"
        case user = "UserRecord"
    }

    let user: UserDTO
    let compCode: Int
}
