import Foundation

@MainActor
@Observable
public final class UserStore {

    // MARK: - Internal Types

    private enum Key: String {
        case id = "current_user_id"
        case nick = "current_user_nick"
        case email = "current_user_email"
    }

    // MARK: - Public Properties

    public private(set) var currentUser: CurrentUser

    // MARK: - Private Properties

    private let storage: UserDefaults

    // MARK: - Public Init

    public convenience init?() {
        self.init(storage: .standard)
    }

    public init?(storage: UserDefaults) {
        guard
            storage.object(forKey: Key.id.rawValue) != nil,
            let savedNick = storage.string(forKey: Key.nick.rawValue),
            let savedEmail = storage.string(forKey: Key.email.rawValue),
            let savedUser = CurrentUser(
                id: storage.integer(forKey: Key.id.rawValue),
                nick: savedNick,
                email: savedEmail
            )
        else {
            Self.logout(storage: storage)
            return nil
        }

        self.currentUser = savedUser
        self.storage = storage
    }

    // MARK: - Public Methods

    public func save(user: UserProfile) -> Bool {
        guard let currentUser = CurrentUser(user: user) else {
            logout()
            return false
        }

        self.currentUser = currentUser
        Self.save(currentUser, storage: storage)
        return true
    }

    @discardableResult
    public static func save(user: UserProfile, storage: UserDefaults = .standard) -> Bool {
        guard let currentUser = CurrentUser(user: user) else {
            logout(storage: storage)
            return false
        }

        save(currentUser, storage: storage)
        return true
    }

    public func logout() {
        Self.logout(storage: storage)
    }

    public func clear() {
        logout()
    }

    public static func logout(storage: UserDefaults = .standard) {
        clearStoredUser(storage: storage)
        TokenManager.shared.clearTokens()
    }

    // MARK: - Private Methods

    private static func save(_ currentUser: CurrentUser, storage: UserDefaults) {
        storage.set(currentUser.id, forKey: Key.id.rawValue)
        storage.set(currentUser.nick, forKey: Key.nick.rawValue)
        storage.set(currentUser.email, forKey: Key.email.rawValue)
    }

    private static func clearStoredUser(storage: UserDefaults) {
        storage.removeObject(forKey: Key.id.rawValue)
        storage.removeObject(forKey: Key.nick.rawValue)
        storage.removeObject(forKey: Key.email.rawValue)
    }
}
