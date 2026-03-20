import Foundation

struct UserSubscribersResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case users = "Users"
        case compCode = "CompCode"
    }

    let users: [UserDTO]
    let compCode: Int
}

