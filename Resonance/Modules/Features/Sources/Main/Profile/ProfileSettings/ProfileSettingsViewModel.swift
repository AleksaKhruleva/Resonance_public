import Foundation
import Core
import Networking

@MainActor
@Observable
final class ProfileSettingsViewModel {

    // MARK: - Internal Types

    enum Intent {
        case loadProfile
        case changeAvatar(Data)
        case deleteAvatar
        case avatarSelectionFailed
        case dismissToast
    }

    enum State: Equatable {
        case idle
        case loadingProfile
        case content
        case updatingAvatar
    }

    // MARK: - Properties

    private(set) var state: State = .idle
    private(set) var toast: ToastItem?
    private(set) var profile: UserProfile?

    private let currentUser: CurrentUser
    private let userService: UserService

    var nick: String {
        profile?.nick ?? currentUser.nick
    }

    var email: String {
        profile?.email ?? currentUser.email
    }

    var avatarData: Data? {
        profile?.avatarData
    }

    var hasAvatar: Bool {
        avatarData?.isEmpty == false
    }

    var isLoading: Bool {
        state == .loadingProfile || state == .updatingAvatar
    }

    var isAvatarActionAvailable: Bool {
        state != .loadingProfile && state != .updatingAvatar
    }

    // MARK: - Internal Init

    init(
        currentUser: CurrentUser,
        userService: UserService = UserService()
    ) {
        self.currentUser = currentUser
        self.userService = userService
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .loadProfile:
            Task { await loadProfile() }
        case .changeAvatar(let imageData):
            Task { await changeAvatar(imageData) }
        case .deleteAvatar:
            Task { await deleteAvatar() }
        case .avatarSelectionFailed:
            showToast(
                message: "Не удалось открыть фотографию",
                kind: .error
            )
        case .dismissToast:
            toast = nil
        }
    }

    // MARK: - Private Methods

    private func loadProfile() async {
        guard profile == nil, state != .loadingProfile else { return }

        state = .loadingProfile
        let result = await userService.getUserProfile(nick: currentUser.nick)

        switch result {
        case .success(let profile):
            self.profile = profile
            state = .content
        case .failure:
            state = .content
            showToast(
                message: "Не удалось загрузить профиль",
                kind: .error
            )
        }
    }

    private func changeAvatar(_ imageData: Data) async {
        guard isAvatarActionAvailable else { return }

        state = .updatingAvatar
        let result = await userService.changeAvatar(
            userId: currentUser.id,
            avatarData: imageData
        )

        switch result {
        case .success:
            updateProfileAvatar(imageData)
            postProfileSettingsUpdated(avatarData: imageData)
            state = .content
            showToast(
                message: "Аватар обновлен",
                kind: .success
            )
        case .failure:
            state = .content
            showToast(
                message: "Не удалось обновить аватар",
                kind: .error
            )
        }
    }

    private func deleteAvatar() async {
        guard isAvatarActionAvailable, hasAvatar else { return }

        state = .updatingAvatar
        let result = await userService.deleteAvatar()

        switch result {
        case .success:
            updateProfileAvatar(nil)
            postProfileSettingsUpdated(avatarData: nil)
            state = .content
            showToast(
                message: "Аватар удален",
                kind: .success
            )
        case .failure:
            state = .content
            showToast(
                message: "Не удалось удалить аватар",
                kind: .error
            )
        }
    }

    private func updateProfileAvatar(_ avatarData: Data?) {
        if let profile {
            self.profile = makeProfile(from: profile, avatarData: avatarData)
        } else {
            self.profile = UserProfile(
                id: currentUser.id,
                email: currentUser.email,
                nick: currentUser.nick,
                avatarData: avatarData,
                isSubscribedByCurrentUser: false,
                postsCount: 0,
                subscribersCount: 0,
                subscriptionsCount: 0
            )
        }
    }

    private func makeProfile(
        from profile: UserProfile,
        avatarData: Data?
    ) -> UserProfile {
        UserProfile(
            id: profile.id,
            email: profile.email,
            nick: profile.nick,
            avatarData: avatarData,
            isSubscribedByCurrentUser: profile.isSubscribedByCurrentUser,
            postsCount: profile.postsCount,
            subscribersCount: profile.subscribersCount,
            subscriptionsCount: profile.subscriptionsCount
        )
    }

    private func showToast(message: String, kind: ToastKind) {
        toast = ToastItem(
            message: message,
            kind: kind,
            position: .bottom
        )
    }

    private func postProfileSettingsUpdated(avatarData: Data?) {
        var userInfo: [String: Any] = [
            ProfileSettingsUpdateNotification.userNickKey: currentUser.nick
        ]

        if let avatarData {
            userInfo[ProfileSettingsUpdateNotification.avatarDataKey] = avatarData
        }

        NotificationCenter.default.post(
            name: .profileSettingsUpdated,
            object: nil,
            userInfo: userInfo
        )
    }
}
