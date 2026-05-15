import SwiftUI
import Networking
import Core

@MainActor
@Observable
final class EnterCodeViewModel: AlertErrorHandling {

    // MARK: - Internal Types

    enum Event: Equatable {
        case submittedCode
        case enteredCorrectCode(accessToken: String)
        case signinCompleted
    }

    enum Intent {
        case startTimer
        case updateCode(String, String)
        case getNewCode
        case retryWithAnotherFlow
    }

    // MARK: - Properties

    var code = ""
    var errorAlertTitle = ""
    var errorAlertMessage = ""
    var showErrorAlert = false
    var showInformationAlert = false

    private(set) var informationAlertTitle = ""
    private(set) var informationAlertMessage = ""
    private(set) var informationAlertMainAction = ""
    private(set) var secondsRemaining = codeTTL
    private(set) var isLoading = false
    private(set) var event: Event?
    private(set) var email: String
    private(set) var authFlow: AuthFlow

    // MARK: - Private Properties

    private var timerTask: Task<Void, Never>?

    private let accessToken: String
    private let authService: AuthService

    private static let codeTTL = 120

    // MARK: - Internal Init

    init(
        authFlow: AuthFlow,
        accessToken: String,
        email: String,
        authService: AuthService = AuthService()
    ) {
        self.email = email
        self.accessToken = accessToken
        self.authFlow = authFlow
        self.authService = authService
    }

    // MARK: - Internal Methods

    func consumeEvent() -> Event? {
        defer { event = nil }
        return event
    }

    func handle(_ intent: Intent) {
        switch intent {
        case .startTimer:
            startTimer()

        case .updateCode(let oldValue, let newValue):
            updateCode(oldValue, newValue)

        case .getNewCode:
            Task { await submitEmailWithCurrentFlow(email: email) }

        case .retryWithAnotherFlow:
            authFlow = authFlow == .signin ? .signup : .signin
            Task { await submitEmailWithCurrentFlow(email: email) }
        }
    }

    // MARK: - Private Methods

    private func updateCode(_ oldValue: String, _ newValue: String) {
        if oldValue.count < 6 && newValue.count == 6 {
            event = .submittedCode
            Task { await submitCodeWithCurrentFlow() }
        } else if newValue.count > 6 {
            code = String(newValue.prefix(6))
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        secondsRemaining = Self.codeTTL

        timerTask = Task {
            while secondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                secondsRemaining -= 1
            }
        }
    }

    private func submitCodeWithCurrentFlow() async {
        isLoading = true
        defer { isLoading = false }

        switch authFlow {
        case .signin:
            await submitCodeWhenSigningIn(code: code)
        case .signup:
            await submitCodeWhenSigningUp(code: code)
        }
    }

    private func submitCodeWhenSigningUp(code: String) async {
        let result = await authService.signupConfirm(code: code, for: email, withToken: accessToken)

        switch result {
        case .success(let response):
            event = .enteredCorrectCode(accessToken: response.accessToken)
        case .failure(let error):
            if error.isBusinessError(code: 100) {
                showError(AlertStrings.wrongCodeMessage, withTitle: AlertStrings.wrongCodeTitle)
            } else {
                showError()
            }
        }
    }

    private func submitCodeWhenSigningIn(code: String) async {
        let result = await authService.signinConfirm(code: code, for: email)

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
                event = .signinCompleted
            } catch {
                showError()
            }
        case .failure(let error):
            if error.isBusinessError(code: 100) {
                showError(AlertStrings.wrongCodeMessage, withTitle: AlertStrings.wrongCodeTitle)
            } else {
                showError()
            }
        }
    }

    private func submitEmailWithCurrentFlow(email: String) async {
        if let error = EmailValidator.validate(email) {
            showError(error, withTitle: AlertStrings.invalidEmailTitle)
            return
        }

        isLoading = true
        defer { isLoading = false }

        switch authFlow {
        case .signin:
            await submitEmailWhenSigningIn(email: email)
        case .signup:
            await submitEmailWhenSigningUp(email: email)
        }
    }

    private func submitEmailWhenSigningUp(email: String) async {
        let result = await authService.signup(with: email)

        switch result {
        case .success:
            startTimer()

        case .failure(let error):
            if error.isBusinessError(code: 100) {
                informationAlertTitle = AlertStrings.accountAlreadyExistsTitle
                informationAlertMessage = AlertStrings.accountAlreadyExistsMessage
                informationAlertMainAction = "Войти"
                showInformationAlert = true
            } else {
                showError()
            }
        }
    }

    private func submitEmailWhenSigningIn(email: String) async {
        let result = await authService.signin(with: email)

        switch result {
        case .success:
            startTimer()

        case .failure(let error):
            if error.isBusinessError(code: 100) {
                informationAlertTitle = AlertStrings.accountNotFoundTitle
                informationAlertMessage = AlertStrings.accountNotFoundMessage
                informationAlertMainAction = "Создать"
                showInformationAlert = true
            } else {
                showError()
            }
        }
    }
}
