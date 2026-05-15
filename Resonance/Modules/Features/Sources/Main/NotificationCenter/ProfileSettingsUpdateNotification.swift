import Foundation

extension Notification.Name {
    static let profileSettingsUpdated = Notification.Name("profileSettingsUpdated")
}

enum ProfileSettingsUpdateNotification {
    static let userNickKey = "userNick"
    static let newUserNickKey = "newUserNick"
    static let avatarWasUpdatedKey = "avatarWasUpdated"
    static let avatarDataKey = "avatarData"
}
