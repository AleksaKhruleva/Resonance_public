import SwiftUI
import Features

@main
struct ResonanceApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var appState = AppState()
    @State private var notificationsManager = NotificationsManager.shared
    @State private var appRouteStore = AppRouteStore()

    var body: some Scene {
        WindowGroup {
            rootView
                .onAppear {
                    delegate.appRouteStore = appRouteStore
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch appState.root {
        case .auth:
            AuthCoordinator {
                appState.finishAuth()
            }

        case .main:
            if let currentUserInfoStore = appState.currentUserInfoStore {
                TabsCoordinator(
                    onLogout: {
                        appState.logout()
                    }
                )
                .environment(currentUserInfoStore)
                .environment(appRouteStore)
                .task {
                    await notificationsManager.requestAuthorizationIfNeeded()
                }
            } else {
                EmptyView()
            }
        }
    }
}
