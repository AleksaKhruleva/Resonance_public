import Foundation

public enum ReportContentType: String {
    case question = "Q"
    case post = "P"
    case answer = "A"
}

public final class ReportService {

    private let networkingManager: NetworkingManager

    public init() {
        self.networkingManager = NetworkingManager()
    }

    public func createReport(
        type: ReportContentType,
        id: Int,
        text: String
    ) async -> NetworkingResult<Void> {
        do {
            let body: [String: Any] = [
                "Type": type.rawValue,
                "Id": id,
                "Text": text
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: ReportActionResponseDTO = try await networkingManager.request(
                endpoint: "/report/create",
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
}
