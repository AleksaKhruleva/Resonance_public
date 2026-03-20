import SwiftUI
import Core

struct PostsCoordinator: View {

    private enum Route: Hashable {
        case profile(ProfileCoordinator.Route)
        case notifications(NotificationsCoordinator.Route)
    }

    @Environment(UserStore.self) private var userStore
    @State private var path = NavigationPath()
    @Binding private var refreshTrigger: Int
    private let onLogout: () -> Void

    init(
        refreshTrigger: Binding<Int> = .constant(0),
        onLogout: @escaping () -> Void = {}
    ) {
        _refreshTrigger = refreshTrigger
        self.onLogout = onLogout
    }

    var body: some View {
        NavigationStack(path: $path) {
            PostsFeedView(
                currentUser: userStore.currentUser,
                refreshTrigger: $refreshTrigger
            ) { authorNick in
                path.append(
                    Route.profile(.profile(userNick: authorNick))
                )
            } onNotificationsTap: {
                path.append(Route.notifications(.notifications))
            }
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
                case .notifications(let notificationsRoute):
                    NotificationsCoordinator(
                        route: notificationsRoute,
                        onRoute: { nextRoute in
                            path.append(Route.notifications(nextRoute))
                        }
                    )
                }
            }
        }
    }
}
