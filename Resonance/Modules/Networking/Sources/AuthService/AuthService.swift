import Foundation
import Core

public final class AuthService {
    
    private let networkingManager: NetworkingManager

    public init() {
        self.networkingManager = NetworkingManager()
    }
    
    public func signin(with email: String) async throws -> SigninResponse {
        let body = ["Email": email]
        let bodyData = try JSONEncoder().encode(body)
        
        return try await networkingManager.request(
            endpoint: "/user/signin/request",
            method: .post,
            body: bodyData
        )
    }
    
    public func signinConfirm(
        code: String,
        for email: String
    ) async -> NetworkingResult<SigninConfirmCodeResponse> {
        do {
            let body = ["Email": email, "VCode": code]
            let bodyData = try JSONEncoder().encode(body)

            let response: SigninConfirmCodeResponseDTO = try await networkingManager.request(
                endpoint: "/user/signin/confirm",
                method: .post,
                body: bodyData
            )

            switch response.compCode {
            case 0:
                let result = response.toDomain()
                return .success(result)
            default:
                let error = BusinessError(compCode: response.compCode)
                return .failure(.business(error))
            }
        } catch {
            return .networkFailure(from: error)
        }
    }
    
    public func signup(with email: String) async throws -> SignupResponse {
        let body = ["Email": email]
        let bodyData = try JSONEncoder().encode(body)
        
        return try await networkingManager.request(
            endpoint: "/user/signup/request",
            method: .post,
            body: bodyData
        )
    }
    
    public func signupConfirm(
        code: String,
        for email: String,
        withToken accessToken: String
    ) async -> NetworkingResult<SignupConfirmCodeResponse> {
        do {
            let body = ["Email": email, "VCode": code]
            let bodyData = try JSONEncoder().encode(body)

            let response: SignupConfirmCodeResponseDTO = try await networkingManager.request(
                endpoint: "/user/signup/confirm",
                method: .post,
                headers: ["Authorization": "Bearer \(accessToken)"],
                body: bodyData
            )

            switch response.compCode {
            case 0:
                let result = response.toDomain()
                return .success(result)
            default:
                let error = BusinessError(compCode: response.compCode)
                return .failure(.business(error))
            }
        } catch {
            return .networkFailure(from: error)
        }
    }
    
    public func signupCommit(
        email: String,
        nick: String,
        withToken accessToken: String
    ) async -> NetworkingResult<SignupCommitResponse> {
        do {
            let body = ["Email": email, "Nick": nick]
            let bodyData = try JSONEncoder().encode(body)

            let response: SignupCommitResponseDTO = try await networkingManager.request(
                endpoint: "/user/signup/commit",
                method: .post,
                headers: ["Authorization": "Bearer \(accessToken)"],
                body: bodyData
            )

            switch response.compCode {
            case 0:
                guard
                    let accessToken = response.accessToken,
                    let refreshToken = response.refreshToken
                else {
                    throw NSError(domain: "Unexpected response", code: 0, userInfo: nil)
                }
                let result = response.toDomain(accessToken: accessToken, refreshToken: refreshToken)
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
