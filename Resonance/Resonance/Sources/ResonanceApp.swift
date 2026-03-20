import SwiftUI
import Features

@main
struct ResonanceApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            switch appState.root {
            case .auth:
                AuthCoordinator() {
                    appState.finishAuth()
                }

            case .main:
                if let userStore = appState.userStore {
                    TabsCoordinator(
                        onLogout: {
                            appState.logout()
                        }
                    )
                        .environment(userStore)
                } else {
                    EmptyView()
                        .task {
                            appState.logout()
                        }
                }
            }
        }
    }
}
