import UIKit
import UserNotifications

public enum NotificationPermissionStatus: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case disabled

    public var isAllowed: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .unknown, .notDetermined, .denied, .disabled:
            return false
        }
    }
}

@MainActor
@Observable
public final class NotificationsManager {

    public static let shared = NotificationsManager()

    public private(set) var status: NotificationPermissionStatus = .unknown

    public var isAllowed: Bool {
        status.isAllowed
    }

    private var didRequestAuthorization = false

    // MARK: - Private Init

    private init() {}

    // MARK: - Public Methods

    public func getNotificationStatus() async -> Bool {
        await refreshStatus()
        return status.isAllowed
    }

    public func refreshStatus() async {
        status = await currentStatus()
    }

    @discardableResult
    public func requestAuthorizationIfNeeded() async -> Bool {
        guard !didRequestAuthorization else {
            await refreshStatus()
            registerForRemoteNotificationsIfAllowed()
            return status.isAllowed
        }

        await refreshStatus()

        guard status == .notDetermined else {
            registerForRemoteNotificationsIfAllowed()
            return status.isAllowed
        }

        didRequestAuthorization = true

        let isGranted = await requestAuthorization()
        await refreshStatus()
        registerForRemoteNotificationsIfAllowed()
        return isGranted && status.isAllowed
    }

    public func updateBadgeCount(with count: Int) {
        let badgeCount = max(0, count)
        UNUserNotificationCenter.current().setBadgeCount(badgeCount) { error in
            if let error {
                print("Failed to update app badge: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Methods

    private func currentStatus() async -> NotificationPermissionStatus {
        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return settings.alertSetting == .disabled ? .disabled : .authorized
        case .provisional:
            return settings.alertSetting == .disabled ? .disabled : .provisional
        case .ephemeral:
            return settings.alertSetting == .disabled ? .disabled : .ephemeral
        @unknown default:
            return .unknown
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func registerForRemoteNotificationsIfAllowed() {
        guard status.isAllowed else { return }

        UIApplication.shared.registerForRemoteNotifications()
    }
}
