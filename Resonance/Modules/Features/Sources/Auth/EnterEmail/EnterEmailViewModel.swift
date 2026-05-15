import SwiftUI
import Networking
import Core

@MainActor
@Observable
final class EnterEmailViewModel: AlertErrorHandling {

    // MARK: - Internal Types

    enum Event: Equatable {
        case submittedEmail(String, accessToken: String)
    }

    enum Intent {
        case submitEmail(email: String)
        case retryWithAnotherFlow(email: String)
    }

    // MARK: - Properties

    var errorAlertTitle = ""
    var errorAlertMessage = ""
    var showErrorAlert = false
    var showInformationAlert = false

    private(set) var informationAlertTitle = ""
    private(set) var informationAlertMessage = ""
    private(set) var informationAlertMainAction = ""
    private(set) var isLoading = false
    private(set) var event: Event?
    private(set) var authFlow: AuthFlow

    private let authService: AuthService

    // MARK: - Internal Init

    init(
        authFlow: AuthFlow,
        authService: AuthService = AuthService()
    ) {
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
        case .submitEmail(let email):
            Task { await submitEmailWithCurrentFlow(email: email) }

        case .retryWithAnotherFlow(let email):
            authFlow = authFlow == .signin ? .signup : .signin
            Task { await submitEmailWithCurrentFlow(email: email) }
        }
    }

    // MARK: - Private Methods

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
        case .success(let response):
            event = .submittedEmail(email, accessToken: response.accessToken)

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
            event = .submittedEmail(email, accessToken: "")

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
