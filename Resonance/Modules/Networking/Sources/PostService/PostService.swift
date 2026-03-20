import Core
import Foundation

public enum PostsFeedMode: String {
    case nick = "nick"
    case followingOrMy = "following_or_my"
}

public final class PostService {

    private let networkingManager: NetworkingManager

    public init() {
        self.networkingManager = NetworkingManager()
    }

    public func getPostsFeed(
        for nick: String? = nil,
        latestPostId: Int,
        batchSize: Int,
        mode: PostsFeedMode
    ) async -> NetworkingResult<[Post]> {
        do {
            let body: [String: Any?] = [
                "PostId": latestPostId,
                "BatchSize": batchSize,
                "Mode": mode.rawValue,
                "Nick": nick
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: PostsFeedResponseDTO = try await networkingManager.request(
                endpoint: "/post/list",
                method: .post,
                authorization: .bearer,
                body: bodyData
            )

            let currentUserId = await TokenManager.shared.userId

            switch response.compCode {
            case 0:
                let result = response.posts.map { $0.toDomain(with: currentUserId) }
                return .success(result)
            default:
                let error = BusinessError(compCode: response.compCode)
                return .failure(.business(error))
            }
        } catch {
            return .networkFailure(from: error)
        }
    }

    public func toggleLike(
        postId: Int,
        isLiked: Bool
    ) async -> NetworkingResult<Int?> {
        do {
            let body = ["PostId": postId]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let endpoint = isLiked ? "/post/like/no" : "/post/like/yes"

            let response: LikeDTO = try await networkingManager.request(
                endpoint: endpoint,
                method: .post,
                authorization: .bearer,
                body: bodyData
            )

            switch response.compCode {
            case 0:
                return .success(response.likesCount)
            default:
                let error = BusinessError(compCode: response.compCode)
                return .failure(.business(error))
            }
        } catch {
            return .networkFailure(from: error)
        }
    }

    public func deletePost(postId: Int) async -> NetworkingResult<Void> {
        do {
            let body = PostDeleteRequestDTO(
                postRecord: PostDeleteRecordDTO(postId: postId)
            )
            let bodyData = try JSONEncoder().encode(body)

            let response: PostDeleteResponseDTO = try await networkingManager.request(
                endpoint: "/post/delete",
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
