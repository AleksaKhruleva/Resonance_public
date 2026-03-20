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
            Task { await submitEmailWithCurrentFlow() }

        case .retryWithAnotherFlow:
            toggleAuthFlow()
            Task { await submitEmailWithCurrentFlow() }
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
            let response = await authService.signinConfirm(code: code, for: email)
            switch response {
            case .success(let response):
                handleSuccessfulSignin(response)
            case .failure(let error):
                if error.isBusinessError(code: 100) {
                    showError(AlertStrings.wrongCodeMessage, withTitle: AlertStrings.wrongCodeTitle)
                } else {
                    showError()
                }
            }
        case .signup:
            let response = await authService.signupConfirm(code: code, for: email, withToken: accessToken)
            switch response {
            case .success(let response):
                if let accessToken = response.accessToken {
                    event = .enteredCorrectCode(accessToken: accessToken)
                    return
                }
                showError()
            case .failure(let error):
                if error.isBusinessError(code: 100) {
                    showError(AlertStrings.wrongCodeMessage, withTitle: AlertStrings.wrongCodeTitle)
                } else {
                    showError()
                }
            }
        }
    }

    private func submitEmailWithCurrentFlow() async {
        if let error = EmailValidator.validate(email) {
            showError(error, withTitle: AlertStrings.invalidEmailTitle)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch authFlow {
            case .signin:
                let response = try await authService.signin(with: email)
                handleSigninResponse(response)

            case .signup:
                let response = try await authService.signup(with: email)
                handleSignupResponse(response)
            }
        } catch {
            showError()
        }
    }

    private func handleSuccessfulSignin(_ response: SigninConfirmCodeResponse) {
        do {
            try TokenManager.shared.saveTokens(access: response.accessToken, refresh: response.refreshToken)
            guard UserStore.save(user: response.user) else {
                showError()
                return
            }
            event = .signinCompleted
        } catch {
            showError()
        }
    }

    private func handleSigninResponse(_ response: SigninResponse) {
        switch response.CompCode {
        case 0:
            startTimer()
        case 100:
            informationAlertTitle = AlertStrings.accountNotFoundTitle
            informationAlertMessage = AlertStrings.accountNotFoundMessage
            informationAlertMainAction = "Создать"
            showInformationAlert = true
        default:
            print(response.CompCode, response.ReasonCodeS)
            showError()
        }
    }

    private func handleSignupResponse(_ response: SignupResponse) {
        switch response.CompCode {
        case 0:
            startTimer()
        case 100:
            informationAlertTitle = AlertStrings.accountAlreadyExistsTitle
            informationAlertMessage = AlertStrings.accountAlreadyExistsMessage
            informationAlertMainAction = "Войти"
            showInformationAlert = true
        default:
            print(response.CompCode, response.ReasonCodeS)
            showError()
        }
    }

    private func toggleAuthFlow() {
        authFlow = authFlow == .signin ? .signup : .signin
    }
}
