import SwiftUI
import Core

@MainActor
@Observable
final class AppState {

    // MARK: - Internal Types

    enum Root {
        case auth
        case main
    }

    // MARK: - Properties

    var root: Root = .auth
    private(set) var userStore: UserStore?

    private let tokenManager = TokenManager.shared

    // MARK: - Internal Init

    init() {
        checkAuthStatus()
    }

    // MARK: - Internal Methods

    func finishAuth() {
        checkAuthStatus()
    }

    func logout() {
        userStore?.logout()
        userStore = nil
        root = .auth
    }

    // MARK: - Private Methods

    private func checkAuthStatus() {
        guard tokenManager.isAuthenticated, let userStore = UserStore() else {
            UserStore.logout()
            self.userStore = nil
            root = .auth
            return
        }

        self.userStore = userStore
        root = .main
    }
}
