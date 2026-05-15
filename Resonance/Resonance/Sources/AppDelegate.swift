import UIKit
import UserNotifications
import Core
import Features

class AppDelegate: NSObject, UIApplicationDelegate {

    @MainActor
    var appRouteStore: AppRouteStore?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken
            .map { String(format: "%02.2hhx", $0) }
            .joined()

        Task {
            await DeviceTokenManager.shared.registerDeviceForAPNS(token: token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier, let route = makeRoute(from: userInfo) {
            Task { @MainActor in
                appRouteStore?.open(route)
            }
        }

        completionHandler()
    }
}

// MARK: - Private Methods

private extension AppDelegate {

    func makeRoute(from userInfo: [AnyHashable: Any]) -> AppRouteStore.Route? {
        guard let notificationJson = userInfo["noticeJson"] as? String,
              let data = notificationJson.data(using: .utf8)
        else {
            return nil
        }

        do {
            let payload = try JSONDecoder().decode(NotificationPayloadDTO.self, from: data)
            switch payload.type {
            case .newFollower:
                guard let initiatorNick = payload.initiatorNick else { return nil }
                return AppRouteStore.Route.userProfile(userNick: initiatorNick)

            case .newQuestion:
                return AppRouteStore.Route.questionDetails(questionId: payload.questionId, answerId: nil)

            case .newAnswer:
                return AppRouteStore.Route.questionDetails(questionId: payload.questionId, answerId: payload.answerId)
            }
        } catch {
            print("Failed to decode notice payload: \(error)")
            return nil
        }
    }
}
