import Core
import Foundation

public final class NotificationService {

    private let networkingManager: NetworkingManager

    public init() {
        self.networkingManager = NetworkingManager()
    }

    public func getNotices(
        noticeId: Int,
        batchSize: Int
    ) async -> NetworkingResult<[Notice]> {
        do {
            let body: [String: Any] = [
                "NoticeId": noticeId,
                "BatchSize": batchSize
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: NoticeListResponseDTO = try await networkingManager.request(
                endpoint: "/notice/list",
                method: .post,
                authorization: .bearer,
                body: bodyData
            )

            switch response.compCode {
            case 0:
                let result = response.notices.map { $0.toDomain() }
                return .success(result)
            default:
                let error = BusinessError(compCode: response.compCode)
                return .failure(.business(error))
            }
        } catch {
            return .networkFailure(from: error)
        }
    }
}
