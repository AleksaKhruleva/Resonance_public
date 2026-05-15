import Foundation
import Core

struct DeviceDTO: Codable {

    enum CodingKeys: String, CodingKey {
        case id = "DeviceId"
        case userId = "UserId"
        case token = "Token"
    }

    let id: Int
    let userId: Int
    let token: String

    func toDomain() -> Device {
        Device(
            id: id,
            userId: userId,
            token: token
        )
    }
}
