import Foundation

struct DeviceUnregisterResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case compCode = "CompCode"
    }
    
    let compCode: Int
}
