import Foundation

@MainActor
@Observable
public final class TokenManager {
    
    public static let shared = TokenManager()

    // MARK: - Public Properties

    public private(set) var accessToken: String?
    public private(set) var refreshToken: String?

    public var userId: Int? {
        guard let token = accessToken else { return nil }
        return extractUserId(from: token)
    }

    private enum Key: String {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
    
    private init() {
        accessToken = get(forKey: .accessToken)
        refreshToken = get(forKey: .refreshToken)
    }
    
    // MARK: - Public Methods

    public func saveTokens(access: String, refresh: String) throws {
        try save(access, forKey: .accessToken)
        try save(refresh, forKey: .refreshToken)
        
        accessToken = access
        refreshToken = refresh
    }
    
    public func clearTokens() {
        delete(forKey: .accessToken)
        delete(forKey: .refreshToken)
        
        accessToken = nil
        refreshToken = nil
    }
    
    public var isAuthenticated: Bool {
        return accessToken != nil
    }
    
    // MARK: - Private Methods

    private func save(_ value: String, forKey key: Key) throws {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func get(forKey key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var data: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &data)
        
        guard status == errSecSuccess,
              let tokenData = data as? Data,
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    private func delete(forKey key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        
        SecItemDelete(query as CFDictionary)
    }

    private func extractUserId(from token: String) -> Int? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        let payloadPart = String(parts[1])

        var base64 = payloadPart
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard
            let data = Data(base64Encoded: base64),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let userId = json["user_id"] as? String {
            return Int(userId)
        }

        return nil
    }
}
