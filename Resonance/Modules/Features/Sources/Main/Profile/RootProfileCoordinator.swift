import SwiftUI
import Core

struct RootProfileCoordinator: View {

    private enum Route: Hashable {
        case profile(ProfileCoordinator.Route)
    }

    @Environment(CurrentUserInfoStore.self) private var currentUserInfoStore
    @State private var path = NavigationPath()
    private let onLogout: () -> Void

    init(onLogout: @escaping () -> Void = {}) {
        self.onLogout = onLogout
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ProfileCoordinator(
                route: .profile(userNick: currentUserInfoStore.nick),
                onLogout: onLogout,
                onRoute: { nextRoute in
                    path.append(Route.profile(nextRoute))
                }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                    case .profile(let profileRoute):
                        ProfileCoordinator(
                            route: profileRoute,
                            onLogout: onLogout,
                            onRoute: { nextRoute in
                                path.append(Route.profile(nextRoute))
                            }
                        )
                }
            }
        }
    }
}
