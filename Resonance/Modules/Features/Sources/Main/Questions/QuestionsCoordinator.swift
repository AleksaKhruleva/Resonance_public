import SwiftUI
import UIComponents
import Core

struct QuestionsCoordinator: View {

    private enum Route: Hashable {
        case profile(ProfileCoordinator.Route)
        case notifications(NotificationsCoordinator.Route)
        case questionDetails(Question)
    }

    private let hasUnreadNotifications = true

    @State private var path = NavigationPath()
    @Binding private var refreshTrigger: Int
    @Binding private var refreshFilter: QuestionsFeedViewModel.FeedFilter?
    private let onLogout: () -> Void

    init(
        refreshTrigger: Binding<Int> = .constant(0),
        refreshFilter: Binding<QuestionsFeedViewModel.FeedFilter?> = .constant(nil),
        onLogout: @escaping () -> Void = {}
    ) {
        _refreshTrigger = refreshTrigger
        _refreshFilter = refreshFilter
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
                    path.append(Route.questionDetails(question))
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
                case .questionDetails(let question):
                    QuestionDetailedView(
                        questionId: question.id,
                        onAuthorTap: { authorNick in
                            path.append(Route.profile(.profile(userNick: authorNick)))
                        }
                    )
                }
            }
        }
    }
}
