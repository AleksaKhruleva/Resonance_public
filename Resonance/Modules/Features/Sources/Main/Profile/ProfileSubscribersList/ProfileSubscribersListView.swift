import SwiftUI
import Core
import UIComponents

struct ProfileSubscribersListView: View {

    @State private var viewModel: ProfileSubscribersListViewModel

    init(
        userNick: String,
        onUserTap: ((String) -> Void)?
    ) {
        _viewModel = State(
            initialValue: ProfileSubscribersListViewModel(
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
        .toolbarTitle("Подписчики")
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
            subscribersList
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

    private var subscribersList: some View {
        List {
            ForEach(viewModel.subscribers) { subscriber in
                UserProfileRow(
                    avatarData: subscriber.avatarData,
                    nick: subscriber.nick,
                    onTap: {
                        viewModel.handle(.openUserProfile(userNick: subscriber.nick))
                    }
                )
                .onAppear {
                    viewModel.handle(.loadNextBatchIfNeeded(userId: subscriber.id))
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
        Text("Здесь пока нет подписчиков 👀 👥")
            .wixFont(.semibold)
    }
}
