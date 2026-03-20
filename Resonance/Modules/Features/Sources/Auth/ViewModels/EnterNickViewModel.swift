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
        case updateNick(String)
        case submitNick
    }

    // MARK: - Properties

    var nick = ""
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
            case .updateNick(let newValue):
                updateNick(newValue)
                
            case .submitNick:
                Task { await submitNick() }
        }
    }
    
    // MARK: - Private Methods

    private func submitNick() async {
        if let error = NickValidator.validate(nick) {
            showError(error.rawValue, withTitle: AlertStrings.invalidNickTitle)
            return
        }
        
        isLoading = true
        defer { isLoading = false }

        let response = await userService.verifyNick(nick)

        switch response {
        case .success:
            showError(AlertStrings.nickTakenMessage, withTitle: AlertStrings.nickTakenTitle)
        case .failure(let error):
            if error.isBusinessError(code: 100) {
                await submitCommit()
            } else {
                showError()
            }
        }
    }
    
    private func submitCommit() async {
        let response = await authService.signupCommit(email: email, nick: nick, withToken: accessToken)

        switch response {
        case .success(let response):
            do {
                try TokenManager.shared.saveTokens(access: response.accessToken, refresh: response.refreshToken)
                guard UserStore.save(user: response.user) else {
                    showError()
                    return
                }
                event = .signupCompleted
            } catch {
                showError()
            }
        case .failure:
            showError()
        }
    }
    
    private func updateNick(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        nick = trimmed.prefix(20).lowercased()
    }
}
