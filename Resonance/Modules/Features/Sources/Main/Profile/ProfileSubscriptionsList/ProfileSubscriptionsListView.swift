import SwiftUI
import Core
import UIComponents

struct ProfileSubscriptionsListView: View {

    @State private var viewModel: ProfileSubscriptionsListViewModel

    init(
        userNick: String,
        onUserTap: ((String) -> Void)?
    ) {
        _viewModel = State(
            initialValue: ProfileSubscriptionsListViewModel(
                userNick: userNick,
                onUserTap: onUserTap
            )
        )
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            content
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitle("Подписки")
        .toolbar(.hidden, for: .tabBar)
        .loading(viewModel.state == .loadingFeed)
        .toast(
            viewModel.toast,
            onTap: {
                viewModel.handle(.dismissToast)
            }
        )
        .onAppear {
            viewModel.handle(.loadFeed)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loadingFeed:
            EmptyView()
        case .loadingNextBatch, .content:
            subscriptionsList
        case .empty:
            emptyStateView
        case .error(let description):
            ErrorView(
                description: description,
                onRetryTap: {
                    viewModel.handle(.loadFeed)
                }
            )
        }
    }

    private var subscriptionsList: some View {
        List {
            ForEach(viewModel.subscriptions) { subscription in
                UserProfileRow(
                    avatarData: subscription.avatarData,
                    nick: subscription.nick,
                    onTap: {
                        viewModel.handle(.openUserProfile(userNick: subscription.nick))
                    }
                )
                .onAppear {
                    viewModel.handle(.loadNextBatchIfNeeded(userId: subscription.id))
                }
            }
            .listRowBackground(Color.clear)
            .listSectionSeparator(.hidden)
            .listRowInsets(.all, 0)

            if viewModel.state == .loadingNextBatch {
                BatchLoadingView()
                    .id(UUID())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.never)
        .scrollContentBackground(.hidden)
    }

    private var emptyStateView: some View {
        Text("Здесь пока нет подписок 👀 👥")
            .wixFont(.semibold)
    }
}
