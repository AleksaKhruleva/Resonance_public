import SwiftUI
import Core

struct ProfileCoordinator: View {

    enum Route: Hashable {
        case profile(userNick: String)
        case settings
        case postDetailed(post: Post)
        case questionDetailed(question: Question)
        case subscribersList(userNick: String)
        case subscriptionsList(userNick: String)
    }

    private let route: Route
    private let onRoute: ((Route) -> Void)?
    private let onLogout: () -> Void

    @Environment(CurrentUserInfoStore.self) private var currentUserInfoStore

    init(
        route: Route,
        onLogout: @escaping () -> Void = {},
        onRoute: ((Route) -> Void)? = nil
    ) {
        self.route = route
        self.onLogout = onLogout
        self.onRoute = onRoute
    }

    var body: some View {
        switch route {
        case .profile(let nick):
            ProfileView(
                nick: nick,
                currentUser: currentUserInfoStore.currentUserInfo,
                onSettingsButtonTap: {
                    onRoute?(.settings)
                },
                onAuthorTap: { authorNick in
                    onRoute?(.profile(userNick: authorNick))
                },
                onPostTap: { post in
                    onRoute?(.postDetailed(post: post))
                },
                onQuestionTap: { question in
                    onRoute?(.questionDetailed(question: question))
                },
                onSubscribersTap: {
                    onRoute?(.subscribersList(userNick: nick))
                },
                onSubscriptionsTap: {
                    onRoute?(.subscriptionsList(userNick: nick))
                }
            )
        case .settings:
            ProfileSettingsView(
                currentUser: currentUserInfoStore.currentUserInfo,
                onLogout: onLogout
            )
        case .subscribersList(let userNick):
            ProfileSubscribersListView(
                userNick: userNick,
                onUserTap: { userNick in
                    onRoute?(.profile(userNick: userNick))
                }
            )
        case .subscriptionsList(let userNick):
            ProfileSubscriptionsListView(
                userNick: userNick,
                onUserTap: { userNick in
                    onRoute?(.profile(userNick: userNick))
                }
            )
        case .postDetailed(let post):
            PostDetailedView(post: post)
        case .questionDetailed(let question):
            QuestionDetailedView(
                questionId: question.id,
                onAuthorTap: { userNick in
                    onRoute?(.profile(userNick: userNick))
                }
            )
        }
    }
}
