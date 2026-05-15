import Core
import Networking

public actor DeviceTokenManager {

    private struct CurrentDeviceInfo: Sendable {
        let deviceId: Int?
        let deviceToken: String?
    }

    public static let shared = DeviceTokenManager()

    private let notificationService: NotificationService

    // MARK: - Private Init

    private init(notificationService: NotificationService = NotificationService()) {
        self.notificationService = notificationService
    }

    // MARK: - Public Methods

    public func registerDeviceForAPNS(token: String) async {
        guard let currentDeviceInfo = await currentDeviceInfo() else { return }
        if currentDeviceInfo.deviceToken == token { return }

        let result = await notificationService.registerDeviceForAPNS(token: token)

        switch result {
        case .success(let device):
            await updateCurrentDevice(deviceId: device.id, deviceToken: device.token)
        case .failure(let error):
            print("Failed to register device token: \(error.localizedDescription)")
        }
    }

    // MARK: - Internal Methods

    func unregisterDeviceFromAPNS() async -> Bool {
        guard let deviceId = await currentDeviceInfo()?.deviceId else { return true }

        let result = await notificationService.unregisterDeviceFromAPNS(deviceId: deviceId)

        switch result {
        case .success:
            return true
        case .failure(let failure):
            print("Failed to unregister device token: \(failure.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Methods

    private func currentDeviceInfo() async -> CurrentDeviceInfo? {
        await MainActor.run {
            guard let currentUserInfoStore = CurrentUserInfoStore() else { return nil }

            return CurrentDeviceInfo(
                deviceId: currentUserInfoStore.deviceId,
                deviceToken: currentUserInfoStore.deviceToken
            )
        }
    }

    private func updateCurrentDevice(deviceId: Int, deviceToken: String) async {
        await MainActor.run {
            CurrentUserInfoStore()?.updateDevice(deviceId: deviceId, deviceToken: deviceToken)
        }
    }
}
