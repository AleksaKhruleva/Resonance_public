import SwiftUI
import Core
import Features

@MainActor
@Observable
final class AppState {

    // MARK: - Internal Types

    enum Root {
        case auth
        case main
    }

    // MARK: - Properties

    private(set) var root: Root = .auth
    private(set) var currentUserInfoStore: CurrentUserInfoStore?

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
        clearDataBeforeLogout()
        root = .auth
    }

    // MARK: - Private Methods

    private func checkAuthStatus() {
        guard tokenManager.isAuthenticated,
              let currentUserInfoStore = CurrentUserInfoStore()
        else {
            clearDataBeforeLogout()
            root = .auth
            return
        }
        
        self.currentUserInfoStore = currentUserInfoStore
        root = .main
    }

    private func clearDataBeforeLogout() {
        NotificationsManager.shared.updateBadgeCount(with: 0)
        CurrentUserInfoStore.clearInfo()
        currentUserInfoStore = nil
        tokenManager.clearTokens()
    }
}
