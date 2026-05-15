import Foundation

@MainActor
@Observable
public final class CurrentUserInfoStore {

    // MARK: - Private Types

    private enum Key: String, CaseIterable {
        case id = "current_user_id"
        case nick = "current_user_nick"
        case email = "current_user_email"
        case deviceId = "current_user_device_id"
        case deviceToken = "current_user_device_token"
    }

    // MARK: - Properties

    public private(set) var currentUserInfo: CurrentUserInfo

    public var id: Int {
        currentUserInfo.id
    }

    public var nick: String {
        currentUserInfo.nick
    }

    public var deviceId: Int? {
        currentUserInfo.deviceId
    }

    public var deviceToken: String? {
        currentUserInfo.deviceToken
    }

    private let storage: UserDefaults

    // MARK: - Public Init

    public convenience init?() {
        self.init(storage: .standard)
    }

    public init?(storage: UserDefaults) {
        guard let currentUser = Self.load(from: storage) else {
            Self.clear(storage: storage)
            return nil
        }

        self.currentUserInfo = currentUser
        self.storage = storage
    }

    // MARK: - Public Methods

    public static func saveInfo(_ currentUserInfo: CurrentUserInfo) {
        save(currentUserInfo, to: .standard)
    }

    public static func clearInfo() {
        clear(storage: .standard)
    }

    public func updateDevice(deviceId: Int, deviceToken: String) {
        let currentUserInfo = CurrentUserInfo(
            id: currentUserInfo.id,
            nick: currentUserInfo.nick,
            email: currentUserInfo.email,
            deviceId: deviceId,
            deviceToken: deviceToken
        )

        self.currentUserInfo = currentUserInfo
        Self.save(currentUserInfo, to: .standard)
    }

    public func updateNick(_ nick: String) {
        let currentUserInfo = CurrentUserInfo(
            id: currentUserInfo.id,
            nick: nick,
            email: currentUserInfo.email,
            deviceId: currentUserInfo.deviceId,
            deviceToken: currentUserInfo.deviceToken
        )

        self.currentUserInfo = currentUserInfo
        Self.save(currentUserInfo, to: .standard)
    }

    // MARK: - Private Methods

    private static func load(from storage: UserDefaults) -> CurrentUserInfo? {
        guard
            let id = storage.object(forKey: Key.id.rawValue) as? Int,
            let nick = storage.string(forKey: Key.nick.rawValue),
            let email = storage.string(forKey: Key.email.rawValue)
        else {
            return nil
        }

        let deviceId = storage.object(forKey: Key.deviceId.rawValue) as? Int
        let deviceToken = storage.string(forKey: Key.deviceToken.rawValue)

        return CurrentUserInfo(
            id: id,
            nick: nick,
            email: email,
            deviceId: deviceId,
            deviceToken: deviceToken
        )
    }

    private static func save(_ currentUser: CurrentUserInfo, to storage: UserDefaults) {
        storage.set(currentUser.id, forKey: Key.id.rawValue)
        storage.set(currentUser.nick, forKey: Key.nick.rawValue)
        storage.set(currentUser.email, forKey: Key.email.rawValue)

        if let deviceId = currentUser.deviceId {
            storage.set(deviceId, forKey: Key.deviceId.rawValue)
        } else {
            storage.removeObject(forKey: Key.deviceId.rawValue)
        }

        if let deviceToken = currentUser.deviceToken {
            storage.set(deviceToken, forKey: Key.deviceToken.rawValue)
        } else {
            storage.removeObject(forKey: Key.deviceToken.rawValue)
        }
    }

    private static func clear(storage: UserDefaults) {
        Key.allCases.forEach {
            storage.removeObject(forKey: $0.rawValue)
        }
    }
}
