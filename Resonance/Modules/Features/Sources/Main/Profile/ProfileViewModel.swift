import SwiftUI
import Core
import Networking

@MainActor
@Observable
final class ProfileViewModel {

    // MARK: - Internal Types

    enum Section: String, CaseIterable, Hashable {
        case posts = "Посты"
        case questions = "Вопросы"
        case answers = "Ответы"
    }

    enum Intent {
        case loadProfile
        case refreshProfile
        case openSettings
        case openAuthorProfile(authorNick: String)
        case openPostDetails(post: Post)
        case openQuestionDetails(question: Question)
        case openSubscribersList
        case openSubscriptionsList
        case postDeleted(authorNick: String)
        case questionDeleted(authorNick: String)
        case bestAnswerChanged(questionId: Int, answerId: Int, isBest: Bool)
        case addressedQuestionPublished
        case profileSettingsUpdated(userNick: String, avatarData: Data?)
        case toggleSubscription
        case dismissToast
    }

    enum State: Equatable {
        case idle
        case loadingProfile
        case refreshingProfile
        case content
        case error(String?)
    }

    // MARK: - Properties

    var userNick: String {
        nick
    }

    var isOwnProfile: Bool {
        nick == currentUser.nick
    }

    private(set) var state: State = .idle
    private(set) var toast: ToastItem?
    private(set) var profile: UserProfile?
    private(set) var isSubscriptionToggleInProgress = false
    var selectedSection: Section = .posts
    let postsSectionViewModel: ProfilePostsSectionViewModel
    let questionsSectionViewModel: ProfileQuestionsSectionViewModel
    let answersSectionViewModel: ProfileAnswersSectionViewModel

    private var lastProfileLoadedAt: Date?

    private let nick: String
    private let currentUser: CurrentUser
    private let userService: UserService
    private let onSettingsButtonTap: (() -> Void)?
    private let onAuthorTap: ((String) -> Void)?
    private let onPostTap: ((Post) -> Void)?
    private let onQuestionTap: ((Question) -> Void)?
    private let onSubscribersTap: (() -> Void)?
    private let onSubscriptionsTap: (() -> Void)?

    private static let profileRefreshInterval: TimeInterval = 2 * 60

    private var isLoading: Bool {
        state == .loadingProfile || state == .refreshingProfile
    }

    private var isRefreshing: Bool {
        lastProfileLoadedAt != nil
    }

    private var shouldUpdateData: Bool {
        guard let lastProfileLoadedAt else { return true }
        return Date().timeIntervalSince(lastProfileLoadedAt) > Self.profileRefreshInterval
    }

    // MARK: - Internal Init

    init(
        nick: String,
        currentUser: CurrentUser,
        userService: UserService = UserService(),
        onSettingsButtonTap: (() -> Void)?,
        onAuthorTap: ((String) -> Void)?,
        onPostTap: ((Post) -> Void)?,
        onQuestionTap: ((Question) -> Void)?,
        onSubscribersTap: (() -> Void)?,
        onSubscriptionsTap: (() -> Void)?
    ) {
        self.nick = nick
        self.currentUser = currentUser
        self.userService = userService
        self.onSettingsButtonTap = onSettingsButtonTap
        self.onAuthorTap = onAuthorTap
        self.onPostTap = onPostTap
        self.onQuestionTap = onQuestionTap
        self.onSubscribersTap = onSubscribersTap
        self.onSubscriptionsTap = onSubscriptionsTap

        self.postsSectionViewModel = ProfilePostsSectionViewModel(
            userNick: nick,
            onPostTap: onPostTap
        )
        self.questionsSectionViewModel = ProfileQuestionsSectionViewModel(
            userNick: nick,
            isOwnProfile: nick == currentUser.nick,
            onAuthorTap: onAuthorTap,
            onQuestionTap: onQuestionTap
        )
        self.answersSectionViewModel = ProfileAnswersSectionViewModel(
            userNick: nick,
            isOwnProfile: nick == currentUser.nick,
            onAuthorTap: onAuthorTap,
            onQuestionTap: onQuestionTap
        )
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .loadProfile:
            Task { await requestProfile() }
        case .refreshProfile:
            Task { await refreshProfile() }
        case .openSettings:
            onSettingsButtonTap?()
        case .openAuthorProfile(let authorNick):
            guard authorNick != nick else { return }
            onAuthorTap?(authorNick)
        case .openPostDetails(let post):
            onPostTap?(post)
        case .openQuestionDetails(let question):
            onQuestionTap?(question)
        case .openSubscribersList:
            guard
                let subscribersCount = profile?.subscribersCount,
                subscribersCount > 0
            else { return }
            onSubscribersTap?()
        case .openSubscriptionsList:
            guard
                let subscriptionsCount = profile?.subscriptionsCount,
                subscriptionsCount > 0
            else { return }
            onSubscriptionsTap?()
        case .postDeleted(let authorNick):
            guard authorNick == nick else { return }
            selectedSection = .posts
            Task { await refreshProfile() }
        case .questionDeleted(let authorNick):
            guard authorNick == nick else { return }
            selectedSection = .questions
            Task { await refreshProfile() }
        case .bestAnswerChanged(let questionId, let answerId, let isBest):
            questionsSectionViewModel.handle(
                .bestAnswerChanged(
                    questionId: questionId,
                    answerId: answerId,
                    isBest: isBest
                )
            )
            answersSectionViewModel.handle(
                .bestAnswerChanged(
                    questionId: questionId,
                    answerId: answerId,
                    isBest: isBest
                )
            )
        case .addressedQuestionPublished:
            toast = ToastItem(
                message: "Вопрос успешно отправлен",
                kind: .success,
                position: .bottom
            )
        case .profileSettingsUpdated(let userNick, let avatarData):
            guard userNick == nick, let profile else { return }
            self.profile = makeProfile(
                from: profile,
                avatarData: avatarData
            )
        case .toggleSubscription:
            Task { await toggleSubscription() }
        case .dismissToast:
            toast = nil
        }
    }

    private func refreshProfile() async {
        guard !isLoading else { return }

        let section = selectedSection

        invalidateSections(except: section)
        await requestProfile(force: true)
        await refreshSection(section)
    }

    // MARK: - Private Methods

    private func requestProfile(force: Bool = false) async {
        guard !isLoading, force || shouldUpdateData else { return }

        state = isRefreshing ? .refreshingProfile : .loadingProfile

        let result = await userService.getUserProfile(nick: nick)

        switch result {
        case .success(let profile):
            self.profile = profile
            lastProfileLoadedAt = Date()
            state = .content
        case .failure(let error):
            if isRefreshing {
                state = .content
                showToast(.refreshFailed)
            } else {
                state = .error(error.localizedDescription)
            }
        }
    }

    private func refreshSection(_ section: Section) async {
        switch section {
        case .posts:
            await postsSectionViewModel.refreshFeed()
        case .questions:
            await questionsSectionViewModel.refreshFeed()
        case .answers:
            await answersSectionViewModel.refreshFeed()
        }
    }

    private func invalidateSections(except section: Section) {
        switch section {
        case .posts:
            questionsSectionViewModel.invalidateFeed()
            answersSectionViewModel.invalidateFeed()
        case .questions:
            postsSectionViewModel.invalidateFeed()
            answersSectionViewModel.invalidateFeed()
        case .answers:
            postsSectionViewModel.invalidateFeed()
            questionsSectionViewModel.invalidateFeed()
        }
    }

    private func toggleSubscription() async {
        guard
            !isOwnProfile,
            !isSubscriptionToggleInProgress,
            let originalProfile = profile
        else {
            return
        }

        isSubscriptionToggleInProgress = true
        defer { isSubscriptionToggleInProgress = false }

        let updatedIsSubscribed = !originalProfile.isSubscribedByCurrentUser
        let subscribersCount = max(
            0,
            originalProfile.subscribersCount + (updatedIsSubscribed ? 1 : -1)
        )

        profile = makeProfile(
            from: originalProfile,
            isSubscribedByCurrentUser: updatedIsSubscribed,
            subscribersCount: subscribersCount
        )

        let result = await userService.toggleSubscription(
            userId: originalProfile.id,
            isSubscribed: originalProfile.isSubscribedByCurrentUser
        )

        switch result {
        case .success:
            break
        case .failure:
            profile = originalProfile
            showToast(
                originalProfile.isSubscribedByCurrentUser
                ? .unsubscribeFailed
                : .subscribeFailed
            )
        }
    }

    private func makeProfile(
        from profile: UserProfile,
        isSubscribedByCurrentUser: Bool,
        subscribersCount: Int
    ) -> UserProfile {
        UserProfile(
            id: profile.id,
            email: profile.email,
            nick: profile.nick,
            avatarData: profile.avatarData,
            isSubscribedByCurrentUser: isSubscribedByCurrentUser,
            postsCount: profile.postsCount,
            subscribersCount: subscribersCount,
            subscriptionsCount: profile.subscriptionsCount
        )
    }

    private func makeProfile(
        from profile: UserProfile,
        avatarData: Data?
    ) -> UserProfile {
        UserProfile(
            id: profile.id,
            email: profile.email,
            nick: profile.nick,
            avatarData: avatarData,
            isSubscribedByCurrentUser: profile.isSubscribedByCurrentUser,
            postsCount: profile.postsCount,
            subscribersCount: profile.subscribersCount,
            subscriptionsCount: profile.subscriptionsCount
        )
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }
}
