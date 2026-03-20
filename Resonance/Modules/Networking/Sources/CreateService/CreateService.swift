import Foundation

public final class CreateService {

    private let networkingManager: NetworkingManager

    public init() {
        self.networkingManager = NetworkingManager()
    }

    public func createPost(
        imageData: Data,
        audioData: Data,
        duration: Int
    ) async -> NetworkingResult<Void> {
        do {
            let mediaBase64String = try PostMediaBase64Encoder(
                imageData: imageData,
                audioData: audioData,
                duration: duration
            ).encodeToBase64String()

            let body = ["Media": mediaBase64String]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: CreatePostResponseDTO = try await networkingManager.request(
                endpoint: "/post/create",
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

    public func createQuestion(
        recipientId: Int,
        isAnonymous: Bool,
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
                "RecipientId": recipientId,
                "Anonymous": isAnonymous ? "Y" : "N",
                "QuestionText": text,
                "Media": mediaBase64String
            ]
            let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

            let response: CreateQuestionResponseDTO = try await networkingManager.request(
                endpoint: "/question/create",
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
