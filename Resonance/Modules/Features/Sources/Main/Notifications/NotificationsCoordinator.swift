import SwiftUI
import Core

struct NotificationsCoordinator: View {

    enum Route: Hashable {
        case notifications
        case profile(ProfileCoordinator.Route)
        case questionDetails(questionId: Int)
    }

    private let route: Route
    private let onRoute: ((Route) -> Void)?

    init(
        route: Route,
        onRoute: ((Route) -> Void)? = nil
    ) {
        self.route = route
        self.onRoute = onRoute
    }

    var body: some View {
        switch route {

        case .notifications:
            NotificationsView(
                onUserTap: { userNick in
                    onRoute?(.profile(.profile(userNick: userNick)))
                },
                onQuestionTap: { questionId in
                    onRoute?(.questionDetails(questionId: questionId))
                },
                onAnswerTap: { questionId, _ in
                    onRoute?(.questionDetails(questionId: questionId))
                }
            )

        case .profile(let profileRoute):
            ProfileCoordinator(
                route: profileRoute,
                onRoute: { nextRoute in
                    onRoute?(.profile(nextRoute))
                }
            )

        case .questionDetails(let questionId):
            QuestionDetailedView(
                questionId: questionId,
                onAuthorTap: { userNick in
                    onRoute?(.profile(.profile(userNick: userNick)))
                }
            )

        }
    }
}
