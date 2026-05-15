import Foundation
import Core

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum AuthorizationPolicy {
    case bearer
    case other
}

final class NetworkingManager {

    private let baseURL: String
    private let session: URLSession

    private static let requestTimeout: TimeInterval = 20

    public init(baseURL: String = "https://resonance-appp.ru/appiii", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        authorization: AuthorizationPolicy,
        headers: [String: String]? = nil,
        body: Data?
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.timeoutInterval = Self.requestTimeout

        var allHeaders = headers ?? [:]
        allHeaders["Content-Type"] = "application/json"

        if authorization == .bearer && allHeaders["Authorization"] == nil {
            guard let accessToken = await TokenManager.shared.accessToken?.nilIfEmpty else {
                throw NetworkingError.missingAccessToken
            }
            allHeaders["Authorization"] = "Bearer \(accessToken)"
        }

        allHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw NetworkingError.httpStatus(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkingError.decodingFailed
        }
    }
}
