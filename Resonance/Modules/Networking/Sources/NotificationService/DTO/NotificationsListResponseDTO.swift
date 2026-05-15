import Foundation

struct NotificationsListResponseDTO: Decodable {

    enum CodingKeys: String, CodingKey {
        case notifications = "Notices"
        case newBadgeCount = "FreshQ"
        case compCode = "CompCode"
    }

    let notifications: [NotificationDTO]
    let newBadgeCount: Int
    let compCode: Int
}
