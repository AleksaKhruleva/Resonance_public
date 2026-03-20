import Core
import Foundation

public enum QuestionsFeedMode: String {
    case all
    case following
    case incoming
    case outgoing

    case my
    case nick
}

public final class QuestionService {

    private let networkingManager: NetworkingManager

    public init() {
        self.networkingManager = NetworkingManager()
    }

    public func getQuestionDetails(
        questionId: Int,
        batchSize: Int
    ) async -> NetworkingResult<Question> {
        do {
            let body: [String: Any] = [
                "QuestionId": questionId,
                "BatchSize": batchSize
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: QuestionDTO = try await networkingManager.request(
                endpoint: "/question/details",
                method: .post,
                authorization: .bearer,
                body: bodyData
            )

            if response.compCode != 0 {
                let error = BusinessError(compCode: response.compCode)
                return .failure(.business(error))
            }

            let currentUserId = await TokenManager.shared.userId
            return .success(response.toDomain(with: currentUserId))
        } catch {
            return .networkFailure(from: error)
        }
    }

    public func getQuestionDetailsNextAnswers(
        questionId: Int,
        batchSize: Int,
        answerId: Int
    ) async -> NetworkingResult<[Answer]> {
        do {
            let body: [String: Any] = [
                "QuestionId": questionId,
                "BatchSize": batchSize,
                "AnswerId": answerId
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: QuestionDetailsNextResponseDTO = try await networkingManager.request(
                endpoint: "/question/details/next",
                method: .post,
                authorization: .bearer,
                body: bodyData
            )

            if let compCode = response.compCode, compCode != 0 {
                let error = BusinessError(compCode: compCode)
                return .failure(.business(error))
            }

            let currentUserId = await TokenManager.shared.userId
            let result = response.answers.map { $0.toDomain(with: currentUserId) }
            return .success(result)
        } catch {
            return .networkFailure(from: error)
        }
    }

    public func getQuestionsFeed(
        for nick: String? = nil,
        questionId: Int,
        batchSize: Int,
        mode: QuestionsFeedMode
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
                endpoint: "/question/list",
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

    public func deleteQuestion(
        questionId: Int,
        authorId: Int
    ) async -> NetworkingResult<Void> {
        do {
            let body = QuestionDeleteRequestDTO(
                questionRecord: QuestionDeleteRecordDTO(
                    questionId: questionId,
                    authorId: authorId
                )
            )
            let bodyData = try JSONEncoder().encode(body)

            let response: QuestionDeleteResponseDTO = try await networkingManager.request(
                endpoint: "/question/delete",
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
