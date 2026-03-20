import Foundation

enum ProfileSettingsAlert: Identifiable {
    
    case editAvatar(hasAvatar: Bool)
    case logout
    case deleteAccount
    
    var id: String {
        switch self {
            case .editAvatar(let hasAvatar):
                return "avatar_\(hasAvatar)"
            case .logout:
                return "logout"
            case .deleteAccount:
                return "deleteAccount"
        }
    }
    
    var title: String {
        switch self {
            case .editAvatar:
                return ""
            case .logout:
                return "Выйти из аккаунта?"
            case .deleteAccount:
                return "Удалить аккаунт?"
        }
    }
    
    var message: String {
        switch self {
            case .editAvatar:
                return ""
            case .logout:
                return "Вы сможете войти снова в любой момент."
            case .deleteAccount:
                return "Это действие нельзя отменить. Все данные аккаунта будут удалены без возможности восстановления."
        }
    }
}
