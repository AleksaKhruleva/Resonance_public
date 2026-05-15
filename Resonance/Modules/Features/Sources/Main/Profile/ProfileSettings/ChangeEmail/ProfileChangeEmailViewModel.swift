import Foundation
import Core
import Networking

@MainActor
@Observable
final class ChangeEmailViewModel {

    // MARK: - Internal Types

    enum Intent {
        case changeEmail(newEmail: String)
    }

    enum State: Equatable {
        case content
        case requestingVerificationCode
    }

    // MARK: - Properties

    private(set) var toast: ToastItem?
    private(set) var state: State = .content

    let currentEmail: String
    private let userService: UserService

    // MARK: - Internal Init

    init(
        currentEmail: String,
        userService: UserService = UserService()
    ) {
        self.currentEmail = currentEmail
        self.userService = userService
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .changeEmail(let newEmail):
            Task { await requestVerificationCode(newEmail: newEmail) }
        }
    }

    // MARK: - Private Methods

    private func requestVerificationCode(newEmail: String) async {
        if let error = EmailValidator.validate(newEmail) {
            toast = ToastItem(message: error, kind: .error)
            return
        }

        state = .requestingVerificationCode

//        let result = await userService.changeNick(newNick: newNick)

//        switch result {
//        case .success:
//            // handle
//            print("abba")
//        case .failure(let error):
//            state = .content
//            showToast(.nickChangingFailed)
//        }
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }
}
