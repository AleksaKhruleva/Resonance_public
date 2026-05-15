import SwiftUI
import Core
import UIComponents

struct ProfileView: View {

    @State private var viewModel: ProfileViewModel
    @State private var headerSize: CGSize = .zero
    @State private var addressedQuestionRecipient: UserProfile?

    private var toolbarTitle: String {
        viewModel.isOwnProfile ? "Ваш профиль" : "Профиль"
    }

    init(
        nick: String,
        currentUser: CurrentUserInfo,
        onSettingsButtonTap: (() -> Void)?,
        onAuthorTap: ((String) -> Void)?,
        onPostTap: ((Post) -> Void)?,
        onQuestionTap: ((Question) -> Void)?,
        onSubscribersTap: (() -> Void)?,
        onSubscriptionsTap: (() -> Void)?
    ) {
        _viewModel = State(
            initialValue: ProfileViewModel(
                nick: nick,
                currentUser: currentUser,
                onSettingsButtonTap: onSettingsButtonTap,
                onAuthorTap: onAuthorTap,
                onPostTap: onPostTap,
                onQuestionTap: onQuestionTap,
                onSubscribersTap: onSubscribersTap,
                onSubscriptionsTap: onSubscriptionsTap
            )
        )
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            GeometryReader { mainProxy in
                content(
                    availableHeight: mainProxy.safeHeight,
                    availableWidth: mainProxy.size.width
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitle(toolbarTitle)
        .toolbar { toolbarButton }
        .loading(viewModel.state == .loadingProfile || viewModel.state == .refreshingProfile)
        .toast(
            viewModel.activeToast,
            onTap: {
                viewModel.handle(.dismissToast)
            }
        )
        .onAppear {
            viewModel.handle(.loadProfile)
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilePostDeleted)) { notification in
            guard
                let authorNick = notification.userInfo?[ProfilePostDeletionNotification.authorNickKey] as? String
            else {
                return
            }
            viewModel.handle(.postDeleted(authorNick: authorNick))
        }
        .onReceive(NotificationCenter.default.publisher(for: .questionDeleted)) { notification in
            guard
                let authorNick = notification.userInfo?[QuestionDeletionNotification.authorNickKey] as? String
            else {
                return
            }
            viewModel.handle(.questionDeleted(authorNick: authorNick))
        }
        .onReceive(NotificationCenter.default.publisher(for: .bestAnswerChanged)) { notification in
            guard
                let questionId = notification.userInfo?[BestAnswerNotification.questionIdKey] as? Int,
                let answerId = notification.userInfo?[BestAnswerNotification.answerIdKey] as? Int,
                let isBest = notification.userInfo?[BestAnswerNotification.isBestKey] as? Bool
            else {
                return
            }
            viewModel.handle(
                .bestAnswerChanged(
                    questionId: questionId,
                    answerId: answerId,
                    isBest: isBest
                )
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileSettingsUpdated)) { notification in
            guard
                let userNick = notification.userInfo?[ProfileSettingsUpdateNotification.userNickKey] as? String
            else {
                return
            }

            let avatarData = notification.userInfo?[ProfileSettingsUpdateNotification.avatarDataKey] as? Data
            let newNick = notification.userInfo?[ProfileSettingsUpdateNotification.newUserNickKey] as? String
            let avatarWasUpdated = notification.userInfo?[ProfileSettingsUpdateNotification.avatarWasUpdatedKey] as? Bool ?? false

            viewModel.handle(
                .profileSettingsUpdated(
                    userNick: userNick,
                    newNick: newNick,
                    avatarData: avatarData,
                    avatarWasUpdated: avatarWasUpdated
                )
            )
        }
        .sheet(item: $addressedQuestionRecipient) { recipient in
            NavigationStack {
                CreateAddressedQuestionView(
                    recipient: recipient,
                    onQuestionPublished: {
                        viewModel.handle(.addressedQuestionPublished)
                    }
                )
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarButton: some ToolbarContent {
        if viewModel.isOwnProfile {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.handle(.openSettings)
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .disabled(viewModel.state != .content)
            }
        }
    }

    @ViewBuilder
    private func content(availableHeight: CGFloat, availableWidth: CGFloat) -> some View {
        switch viewModel.state {
        case .idle, .loadingProfile:
            EmptyView()
        case .refreshingProfile, .content:
            profileContent(totalHeight: availableHeight, availableWidth: availableWidth)
        case .error(let description):
            ErrorView(
                description: description,
                onRetryTap: {
                    viewModel.handle(.loadProfile)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func profileContent(totalHeight: CGFloat, availableWidth: CGFloat) -> some View {
        if let profile = viewModel.profile {
            ScrollView {
                VStack(spacing: 16) {
                    Group {
                        AvatarView(imageData: profile.avatarData, frame: 160)

                        Text(profile.nick)
                            .wixFont(.bold, size: 20)

                        if !viewModel.isOwnProfile {
                            HStack(spacing: 8) {
                                askQuestionButton(for: profile)
                                    .hidden()
                                    .allowsHitTesting(false)

                                if profile.isSubscribedByCurrentUser {
                                    unsubscribeButton
                                } else {
                                    subscribeButton
                                }

                                askQuestionButton(for: profile)
                            }
                        }

                        HStack(spacing: 0) {
                            ProfileStatisticsItem(
                                title: "Посты",
                                value: profile.postsCount,
                                onTap: nil
                            )

                            ProfileStatisticsItem(
                                title: "Подписчики",
                                value: profile.subscribersCount,
                                onTap: {
                                    viewModel.handle(.openSubscribersList)
                                }
                            )

                            ProfileStatisticsItem(
                                title: "Подписки",
                                value: profile.subscriptionsCount,
                                onTap: {
                                    viewModel.handle(.openSubscriptionsList)
                                }
                            )
                        }

                        Picker("Раздел профиля", selection: $viewModel.selectedSection) {
                            ForEach(ProfileViewModel.Section.allCases, id: \.self) { section in
                                Text(section.rawValue)
                                    .tag(section)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, AppSize.horizontalPadding)
                    .background(Color.clear.readSize($headerSize))

                    sectionContent(
                        for: viewModel.selectedSection,
                        minHeight: totalHeight - headerSize.height,
                        availableWidth: availableWidth
                    )
                }
            }
            .scrollIndicators(.never)
            .refreshable {
                viewModel.handle(.refreshProfile)
            }
        }
    }

    private var subscribeButton: some View {
        Button {
            viewModel.handle(.toggleSubscription)
        } label: {
            Text("Подписаться")
                .wixFont(.bold, color: AppColor.lightText)
                .frame(width: 120)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .disabled(viewModel.isSubscriptionToggleInProgress)
    }

    private var unsubscribeButton: some View {
        Button {
            viewModel.handle(.toggleSubscription)
        } label: {
            Text("Вы подписаны")
                .wixFont(.bold)
                .frame(width: 120)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glass)
        .disabled(viewModel.isSubscriptionToggleInProgress)
    }

    private func askQuestionButton(for profile: UserProfile) -> some View {
        Button {
            addressedQuestionRecipient = profile
        } label: {
            Image(systemName: "questionmark.message.fill")
                .wixFont(.bold, color: AppColor.lightText)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
    }

    @ViewBuilder
    private func sectionContent(for section: ProfileViewModel.Section, minHeight: CGFloat, availableWidth: CGFloat) -> some View {
        let minHeight = max(0, minHeight)
        let sectionContentWidth = max(0, availableWidth - AppSize.horizontalPadding * 2)

        switch section {
        case .posts:
            ProfilePostsSectionView(
                viewModel: viewModel.postsSectionViewModel,
                minHeight: minHeight
            )
        case .questions:
            ProfileQuestionsSectionView(
                viewModel: viewModel.questionsSectionViewModel,
                minHeight: minHeight,
                availableWidth: sectionContentWidth
            )
        case .answers:
            ProfileAnswersSectionView(
                viewModel: viewModel.answersSectionViewModel,
                minHeight: minHeight,
                availableWidth: sectionContentWidth
            )
        }
    }
}
