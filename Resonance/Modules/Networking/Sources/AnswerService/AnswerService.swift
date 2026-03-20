import Core
import Foundation

public enum AnswersFeedMode: String {
    case my
    case nick
}

public final class AnswerService {

    private let networkingManager: NetworkingManager

    public init() {
        self.networkingManager = NetworkingManager()
    }

    public func getAnswersFeed(
        for nick: String? = nil,
        questionId: Int,
        batchSize: Int,
        mode: AnswersFeedMode
    ) async -> NetworkingResult<[Question]> {
        do {
            let body: [String: Any?] = [
                "QuestionId": questionId,
                "BatchSize": batchSize,
                "Mode": mode.rawValue,
                "Nick": nick
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: QuestionsFeedResponseDTO = try await networkingManager.request(
                endpoint: "/answer/list",
                method: .post,
                authorization: .bearer,
                body: bodyData
            )

            let currentUserId = await TokenManager.shared.userId

            switch response.compCode {
            case 0:
                let result = response.questions.map { $0.toDomain(with: currentUserId) }
                return .success(result)
            default:
                let error = BusinessError(compCode: response.compCode)
                return .failure(.business(error))
            }
        } catch {
            return .networkFailure(from: error)
        }
    }

    public func createAnswer(
        questionId: Int,
        isPrivate: Bool,
        text: String,
        audioData: Data?,
        duration: Int?
    ) async -> NetworkingResult<Void> {
        do {
            let mediaBase64String: String
            if let audioData, let duration {
                mediaBase64String = try QuestionMediaBase64Encoder(
                    audioData: audioData,
                    duration: duration
                ).encodeToBase64String()
            } else {
                mediaBase64String = ""
            }

            let body: [String: Any] = [
                "QuestionId": questionId,
                "Private": isPrivate ? "Y" : "N",
                "AnswerText": text,
                "Media": mediaBase64String
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: AnswerActionResponseDTO = try await networkingManager.request(
                endpoint: "/answer/create",
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

    public func toggleLike(
        answerId: Int,
        isLiked: Bool
    ) async -> NetworkingResult<Int?> {
        do {
            let body = ["AnswerId": answerId]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let endpoint = isLiked ? "/answer/like/no" : "/answer/like/yes"

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

    public func deleteAnswer(answerId: Int) async -> NetworkingResult<Void> {
        do {
            let body = ["AnswerId": answerId]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: AnswerActionResponseDTO = try await networkingManager.request(
                endpoint: "/answer/delete",
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

    public func markBestAnswer(
        questionId: Int,
        answerId: Int,
        isBest: Bool
    ) async -> NetworkingResult<Void> {
        do {
            let body: [String: Int]
            let endpoint: String

            if isBest {
                body = [
                    "QuestionId": questionId,
                    "AnswerId": answerId
                ]
                endpoint = "/answer/best/yes"
            } else {
                body = ["AnswerId": answerId]
                endpoint = "/answer/best/no"
            }

            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: AnswerActionResponseDTO = try await networkingManager.request(
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
}
