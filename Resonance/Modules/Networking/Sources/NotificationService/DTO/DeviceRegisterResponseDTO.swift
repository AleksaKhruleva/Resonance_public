import Foundation

struct DeviceRegisterResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case device = "DeviceRecord"
        case compCode = "CompCode"
    }

    let device: DeviceDTO
    let compCode: Int
}
