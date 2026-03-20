import Foundation
import Core

public final class SearchService {

    private let networkingManager: NetworkingManager

    public init() {
        self.networkingManager = NetworkingManager()
    }

    public func findUsers(
        by nick: String,
        offset: Int,
        batchSize: Int
    ) async -> NetworkingResult<[UserProfile]> {
        do {
            let body = FindUsersRequestDTO(
                nick: nick,
                offset: offset,
                batchSize: batchSize
            )
            let bodyData = try JSONEncoder().encode(body)

            let response: SearchUsersResponseDTO = try await networkingManager.request(
                endpoint: "/nick/search",
                method: .post,
                authorization: .bearer,
                body: bodyData
            )

            switch response.compCode {
            case 0:
                let result = response.users.map { $0.toDomain() }
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

private struct FindUsersRequestDTO: Encodable {

    enum CodingKeys: String, CodingKey {
        case nick = "Nick"
        case offset = "Offset"
        case batchSize = "BatchSize"
    }

    let nick: String
    let offset: Int
    let batchSize: Int
}
