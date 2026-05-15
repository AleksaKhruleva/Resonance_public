import Foundation

public enum NetworkingResult<Success> {
    case success(Success)
    case failure(NetworkingFailure)
}


public enum NetworkingFailure: LocalizedError {
    case network(NetworkingError)
    case business(BusinessError)

    public var errorDescription: String? {
        switch self {
        case .network(let error):
            return error.localizedDescription
        case .business(let error):
            return error.localizedDescription
        }
    }
}

public extension NetworkingFailure {
    func isBusinessError(code: Int) -> Bool {
        guard case .business(let error) = self, error.compCode == code else { return false }
        return true
    }
}

public enum NetworkingError: LocalizedError {
    case invalidURL
    case decodingFailed
    case noConnection
    case missingAccessToken
    case missingUserEmail
    case httpStatus(Int)
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL"
        case .decodingFailed:
            return "Ошибка обработки данных"
        case .noConnection:
            return "Нет подключения к интернету"
        case .missingAccessToken:
            return "Требуется авторизация. Access token отсутствует"
        case .missingUserEmail:
            return "Email текущего пользователя отсутствует"
        case .httpStatus(let statusCode):
            return "Ошибка HTTP. Код: \(statusCode)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

public struct BusinessError: LocalizedError, Equatable {
    public let compCode: Int

    public init(compCode: Int) {
        self.compCode = compCode
    }

    public var errorDescription: String? {
        return "Ошибка бизнес-логики. Код: \(compCode)."
    }
}

extension NetworkingResult {
    static func networkFailure(from error: Error) -> NetworkingResult<Success> {
        if let networkingError = error as? NetworkingError {
            return .failure(.network(networkingError))
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .timedOut:
                return .failure(.network(.noConnection))
            default:
                return .failure(.network(.unknown(urlError)))
            }
        }

        return .failure(.network(.unknown(error)))
    }
}
