import Foundation

extension Notification.Name {
    static let profileSettingsUpdated = Notification.Name("profileSettingsUpdated")
}

enum ProfileSettingsUpdateNotification {
    static let userNickKey = "userNick"
    static let avatarDataKey = "avatarData"
}
