import SwiftUI
import Networking
import Core

@MainActor
@Observable
final class EnterNickViewModel: AlertErrorHandling {

    // MARK: - Internal Types

    enum Event {
        case signupCompleted
    }

    enum Intent {
        case submitNick(nick: String)
    }

    // MARK: - Properties

    var errorAlertTitle = ""
    var errorAlertMessage = ""
    var showErrorAlert = false

    private(set) var isLoading = false
    private(set) var event: Event?

    private let accessToken: String
    private let email: String
    private let authService: AuthService
    private let userService: UserService

    // MARK: - Internal Init

    init(
        accessToken: String,
        email: String,
        authService: AuthService = AuthService(),
        userService: UserService = UserService()
    ) {
        self.accessToken = accessToken
        self.email = email
        self.authService = authService
        self.userService = userService
    }

    // MARK: - Internal Methods

    func consumeEvent() -> Event? {
        defer { event = nil }
        return event
    }

    func handle(_ intent: Intent) {
        switch intent {
        case .submitNick(let nick):
            Task { await submitNick(nick) }
        }
    }

    // MARK: - Private Methods

    private func submitNick(_ nick: String) async {
        if let error = NickValidator.validate(nick) {
            showError(error.rawValue, withTitle: AlertStrings.invalidNickTitle)
            return
        }

        isLoading = true
        defer { isLoading = false }

        let result = await userService.checkNickExistence(nick)

        switch result {
        case .success:
            // Ник уже занят
            showError(AlertStrings.nickTakenMessage, withTitle: AlertStrings.nickTakenTitle)
        case .failure(let error):
            if error.isBusinessError(code: 100) {
                // Ник не занят
                await submitCreateAccount(nick: nick)
            } else {
                showError()
            }
        }
    }

    private func submitCreateAccount(nick: String) async {
        let result = await authService.createAccount(
            email: email,
            nick: nick,
            accessToken: accessToken
        )

        switch result {
        case .success(let response):
            do {
                try TokenManager.shared.saveTokens(access: response.accessToken, refresh: response.refreshToken)
                let currentUserInfo = CurrentUserInfo(
                    id: response.user.id,
                    nick: response.user.nick,
                    email: response.user.email,
                    deviceId: nil,
                    deviceToken: nil
                )
                CurrentUserInfoStore.saveInfo(currentUserInfo)
                event = .signupCompleted
            } catch {
                showError()
            }
        case .failure:
            showError()
        }
    }
}
