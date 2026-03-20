import UserNotifications

public final class NotificationPermissionService {
    
    public init() {}
    
    public func getNotificationStatus() async -> Bool {
        let settings = await notificationSettings()
        
        switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return settings.alertSetting != .disabled
            case .denied, .notDetermined:
                return false
            @unknown default:
                return false
        }
    }
    
    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }
}
