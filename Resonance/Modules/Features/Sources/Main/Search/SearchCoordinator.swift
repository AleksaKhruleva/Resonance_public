import SwiftUI
import Core
import UIComponents

struct SearchCoordinator: View {

    private enum Route: Hashable {
        case profile(ProfileCoordinator.Route)
    }

    @State private var path = NavigationPath()
    private let onLogout: () -> Void

    init(onLogout: @escaping () -> Void = {}) {
        self.onLogout = onLogout
    }

    var body: some View {
        NavigationStack(path: $path) {
            SearchView(
                onUserTap: { authorNick in
                    path.append(Route.profile(.profile(userNick: authorNick)))
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
