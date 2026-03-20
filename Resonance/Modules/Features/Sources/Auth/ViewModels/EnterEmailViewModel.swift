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
        case updateEmail(String)
        case submitEmail
        case retryWithAnotherFlow
    }

    // MARK: - Properties

    var email = ""
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
            case .updateEmail(let newValue):
                updateEmail(newValue)
                
            case .submitEmail:
                Task { await submitEmailWithCurrentFlow() }
                
            case .retryWithAnotherFlow:
                toggleAuthFlow()
                Task { await submitEmailWithCurrentFlow() }
        }
    }
    
    // MARK: - Private Methods

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
    
    private func handleSigninResponse(_ response: SigninResponse) {
        switch response.CompCode {
            case 0:
                event = .submittedEmail(email, accessToken: "")
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
                guard let accessToken = response.JwtAccess else {
                    showError()
                    return
                }
                event = .submittedEmail(email, accessToken: accessToken)
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
    
    private func updateEmail(_ newValue: String) {
        email = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func toggleAuthFlow() {
        authFlow = authFlow == .signin ? .signup : .signin
    }
}
