import SwiftUI
import UIComponents
import Core

struct QuestionsCoordinator: View {

    private enum Route: Hashable {
        case profile(ProfileCoordinator.Route)
        case notifications(NotificationsCoordinator.Route)
        case questionDetails(questionId: Int)
    }

    private let onLogout: () -> Void

    @Environment(AppRouteStore.self) private var appRouteStore

    @Binding private var refreshTrigger: Int
    @Binding private var refreshFilter: FeedFilter?
    @Binding private var deepLinkRoute: QuestionsDeepLinkRoute?

    @State private var path = NavigationPath()

    init(
        refreshTrigger: Binding<Int>,
        refreshFilter: Binding<FeedFilter?>,
        deepLinkRoute: Binding<QuestionsDeepLinkRoute?> = .constant(nil),
        onLogout: @escaping () -> Void = {}
    ) {
        _refreshTrigger = refreshTrigger
        _refreshFilter = refreshFilter
        _deepLinkRoute = deepLinkRoute
        self.onLogout = onLogout
    }

    var body: some View {
        NavigationStack(path: $path) {
            QuestionsFeedView(
                refreshTrigger: $refreshTrigger,
                refreshFilter: $refreshFilter,
                onAuthorTap: { authorNick in
                    path.append(Route.profile(.profile(userNick: authorNick)))
                },
                onQuestionTap: { question in
                    path.append(Route.questionDetails(questionId: question.id))
                },
                onNotificationsTap: {
                    path.append(Route.notifications(.notifications))
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
                case .notifications(let notificationsRoute):
                    NotificationsCoordinator(
                        route: notificationsRoute,
                        onRoute: { nextRoute in
                            path.append(Route.notifications(nextRoute))
                        }
                    )
                case .questionDetails(let questionId):
                    QuestionDetailedView(
                        questionId: questionId,
                        onAuthorTap: { authorNick in
                            path.append(Route.profile(.profile(userNick: authorNick)))
                        }
                    )
                }
            }
            .onAppear {
                handleDeepLinkRoute(deepLinkRoute)
            }
            .onChange(of: deepLinkRoute) { _, route in
                handleDeepLinkRoute(route)
            }
        }
    }

    private func handleDeepLinkRoute(_ route: QuestionsDeepLinkRoute?) {
        guard let route else { return }

        path = NavigationPath()
        switch route {
        case .profile(let userNick):
            path.append(Route.profile(.profile(userNick: userNick)))
        case .questionDetails(let questionId):
            path.append(Route.questionDetails(questionId: questionId))
        }
        deepLinkRoute = nil
        appRouteStore.clear()
    }
}
