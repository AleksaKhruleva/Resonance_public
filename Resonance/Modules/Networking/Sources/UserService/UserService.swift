import Foundation
import Core

public final class UserService {

    private let networkingManager: NetworkingManager

    public init() {
        self.networkingManager = NetworkingManager()
    }

    public func checkNickExistence(_ nick: String) async -> NetworkingResult<Void> {
        do {
            let body = ["Nick": nick]
            let bodyData = try JSONEncoder().encode(body)

            let response: UserNickVerifyResponseDTO = try await networkingManager.request(
                endpoint: "/verify/existence/nick",
                method: .post,
                authorization: .other,
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

    public func getUserProfile(nick: String) async -> NetworkingResult<UserProfile> {
        do {
            let body = ["Nick": nick]
            let bodyData = try JSONEncoder().encode(body)

            let response: UserProfileResponseDTO = try await networkingManager.request(
                endpoint: "/user/profile/full",
                method: .post,
                authorization: .bearer,
                body: bodyData
            )

            switch response.compCode {
            case 0:
                return .success(response.user.toDomain())
            default:
                let error = BusinessError(compCode: response.compCode)
                return .failure(.business(error))
            }
        } catch {
            return .networkFailure(from: error)
        }
    }

    public func getUserSubscribers(
        userNick: String,
        latestUserId: Int,
        batchSize: Int
    ) async -> NetworkingResult<[UserProfile]> {
        do {
            let body: [String: Any] = [
                "Nick": userNick,
                "UserId": latestUserId,
                "BatchSize": batchSize
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: UserSubscribersResponseDTO = try await networkingManager.request(
                endpoint: "/follower/list",
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

    public func getUserSubscriptions(
        userNick: String,
        latestUserId: Int,
        batchSize: Int
    ) async -> NetworkingResult<[UserProfile]> {
        do {
            let body: [String: Any] = [
                "Nick": userNick,
                "UserId": latestUserId,
                "BatchSize": batchSize
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: UserSubscriptionsResponseDTO = try await networkingManager.request(
                endpoint: "/blogger/list",
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

    public func toggleSubscription(
        userId: Int,
        isSubscribed: Bool
    ) async -> NetworkingResult<Void> {
        do {
            let body = ["UserId": userId]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let endpoint = isSubscribed ? "/follow/no" : "/follow/yes"
            let response: UserSubscribeResponseDTO = try await networkingManager.request(
                endpoint: endpoint,
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

    public func changeAvatar(
        userId: Int,
        avatarData: Data
    ) async -> NetworkingResult<Void> {
        do {
            let body: [String: Any] = [
                "UserRecord": [
                    "UserId": userId
                ],
                "MediaRecord": [
                    "Type": "A",
                    "Media": avatarData.base64EncodedString()
                ]
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: UserAvatarChangeResponseDTO = try await networkingManager.request(
                endpoint: "/user/change/ava",
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

    public func deleteAvatar() async -> NetworkingResult<Void> {
        do {
            let body: [String: Any] = [
                "MediaRecord": [
                    "Type": "A",
                    "Media": ""
                ]
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: UserAvatarChangeResponseDTO = try await networkingManager.request(
                endpoint: "/user/change/ava",
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

    public func changeNick(newNick: String) async -> NetworkingResult<Void> {
        do {
            guard let currentUserId = await TokenManager.shared.userId else {
                return .failure(.business(BusinessError(compCode: -1)))
            }
            let body: [String: Any] = [
                "UserId": currentUserId,
                "Nick": newNick
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: UserNickChangeResponseDTO = try await networkingManager.request(
                endpoint: "/user/change/nick",
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

    public func deleteAccount() async -> NetworkingResult<Void> {
        do {
            guard let currentUserId = await TokenManager.shared.userId else {
                return .failure(.business(BusinessError(compCode: -1)))
            }
            let body = [ "UserId": currentUserId]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: UserDeleteResponseDTO = try await networkingManager.request(
                endpoint: "/user/delete",
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
