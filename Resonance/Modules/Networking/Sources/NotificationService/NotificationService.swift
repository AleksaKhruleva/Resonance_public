import Core
import Foundation

public final class NotificationService {

    private let networkingManager: NetworkingManager

    public init() {
        self.networkingManager = NetworkingManager()
    }

    public func registerDeviceForAPNS(token: String) async -> NetworkingResult<Device> {
        do {
            let body = ["Token": token]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: DeviceRegisterResponseDTO = try await networkingManager.request(
                endpoint: "/device/create",
                method: .post,
                authorization: .bearer,
                body: bodyData
            )

            switch response.compCode {
            case 0:
                let result = response.device.toDomain()
                return .success(result)
            default:
                let error = BusinessError(compCode: response.compCode)
                return .failure(.business(error))
            }
        } catch {
            return .networkFailure(from: error)
        }
    }

    public func unregisterDeviceFromAPNS(deviceId: Int) async -> NetworkingResult<Void> {
        do {
            let body = ["DeviceId": deviceId]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: DeviceUnregisterResponseDTO = try await networkingManager.request(
                endpoint: "/device/delete",
                method: .post,
                authorization: .bearer,
                body: bodyData
            )

            switch response.compCode {
            case 0:
                return .success(())
            default:
                let error = BusinessError(compCode: response.compCode)
                return .failure(.business(error))
            }
        } catch {
            return .networkFailure(from: error)
        }
    }

    public func getNotificationsFeed(
        notificationId: Int,
        batchSize: Int
    ) async -> NetworkingResult<([ResonanceNotification], Int)> {
        do {
            let body = [
                "NoticeId": notificationId,
                "BatchSize": batchSize
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: NotificationsListResponseDTO = try await networkingManager.request(
                endpoint: "/notice/list",
                method: .post,
                authorization: .bearer,
                body: bodyData
            )

            switch response.compCode {
            case 0:
                let decoder = JSONDecoder()
                let result = response.notifications.compactMap { notificationDTO -> ResonanceNotification? in
                    guard let data = notificationDTO.payload.data(using: .utf8),
                          let payload = try? decoder.decode(NotificationPayloadDTO.self, from: data)
                    else {
                        return nil
                    }

                    return notificationDTO.toDomain(with: payload)
                }
                return .success((result, response.newBadgeCount))
            default:
                let error = BusinessError(compCode: response.compCode)
                return .failure(.business(error))
            }
        } catch {
            return .networkFailure(from: error)
        }
    }
}
