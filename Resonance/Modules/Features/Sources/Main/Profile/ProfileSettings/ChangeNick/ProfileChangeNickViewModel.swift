import Foundation
import Core
import Networking

@MainActor
@Observable
final class ChangeNickViewModel {

    // MARK: - Internal Types

    enum Intent {
        case changeNick(newNick: String)
        case dismissAlert
        case dismissToast
    }

    enum State: Equatable {
        case content
        case loading
    }

    struct Alert {
        let title: String
        let message: String
    }

    // MARK: - Properties

    private(set) var toast: ToastItem?
    private(set) var alert: Alert?
    private(set) var state: State = .content
    private(set) var shouldDismiss = false

    let currentNick: String
    private let currentUserInfoStore: CurrentUserInfoStore
    private let userService: UserService

    // MARK: - Internal Init

    init(
        currentNick: String,
        currentUserInfoStore: CurrentUserInfoStore,
        userService: UserService = UserService()
    ) {
        self.currentNick = currentNick
        self.currentUserInfoStore = currentUserInfoStore
        self.userService = userService
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .changeNick(let newNick):
            Task { await changeNick(newNick: newNick) }
        case .dismissAlert:
            alert = nil
        case .dismissToast:
            toast = nil
        }
    }

    // MARK: - Private Methods

    private func changeNick(newNick: String) async {
        guard state != .loading, newNick != currentNick else { return }

        if let error = NickValidator.validate(newNick) {
            alert = Alert(title: AlertStrings.invalidNickTitle, message: error.rawValue)
            state = .content
            return
        }

        state = .loading

        let isNickTakenResult = await userService.checkNickExistence(newNick)

        switch isNickTakenResult {
        case .success:
            // Ник уже занят
            state = .content
            alert = Alert(
                title: AlertStrings.nickTakenTitle,
                message: AlertStrings.nickTakenMessage
            )
        case .failure(let error):
            if error.isBusinessError(code: 100) {
                // Ник не занят
                await tryToChangeNick(for: newNick)
            } else {
                state = .content
                alert = Alert(
                    title: AlertStrings.errorTitle,
                    message: AlertStrings.errorMessage
                )
            }
        }
    }

    private func tryToChangeNick(for newNick: String) async {
        state = .loading

        let result = await userService.changeNick(newNick: newNick)

        switch result {
        case .success:
            currentUserInfoStore.updateNick(newNick)
            postProfileSettingsUpdated(newNick: newNick)
            state = .content
            showToast(.nickChanged)
            shouldDismiss = true
        case .failure:
            state = .content
            alert = Alert(
                title: AlertStrings.errorTitle,
                message: AlertStrings.errorMessage
            )
        }
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }

    private func postProfileSettingsUpdated(newNick: String) {
        let userInfo: [String: Any] = [
            ProfileSettingsUpdateNotification.userNickKey: currentNick,
            ProfileSettingsUpdateNotification.newUserNickKey: newNick,
            ProfileSettingsUpdateNotification.avatarWasUpdatedKey: false
        ]

        NotificationCenter.default.post(
            name: .profileSettingsUpdated,
            object: nil,
            userInfo: userInfo
        )
    }
}
