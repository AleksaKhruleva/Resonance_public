import SwiftUI
import Core
import UIComponents

struct NotificationsView: View {

    @State private var viewModel: NotificationsViewModel

    init(
        onUserTap: ((String) -> Void)?,
        onQuestionTap: ((Int) -> Void)?,
        onAnswerTap: ((Int, Int) -> Void)?
    ) {
        _viewModel = State(
            initialValue: NotificationsViewModel(
                notificationsManager: NotificationsManager.shared,
                onUserTap: onUserTap,
                onQuestionTap: onQuestionTap,
                onAnswerTap: onAnswerTap
            )
        )
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            content
        }
        .toolbarTitle("Уведомления")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .tabBar)
        .loading(viewModel.state == .loadingFeed || viewModel.state == .refreshingFeed)
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
        case .loadingNextBatch, .refreshingFeed, .content:
            notificationsList
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

    private var notificationsList: some View {
        List {
            ForEach(viewModel.notificationSections) { section in
                Section {
                    ForEach(section.notifications) { notification in
                        NotificationRow(
                            notification: notification,
                            onAvatarTap: {
                                viewModel.handle(.openUserProfile(userNick: notification.initiatorNick))
                            },
                            onRowBodyTap: {
                                viewModel.handle(.openNotification(notification: notification))
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.horizontal, AppSize.horizontalPadding)
                        .listRowInsets(.vertical, .zero)
                        .onAppear {
                            viewModel.handle(.loadNextBatchIfNeeded(notificationId: notification.id))
                        }
                    }
                } header: {
                    Text(section.period.title)
                        .wixFont(.semibold)
                        .textCase(nil)
                        .listRowInsets(.horizontal, AppSize.horizontalPadding)
                        .listRowInsets(.vertical, 0)
                }
                .listRowBackground(Color.clear)
                .listSectionSeparator(.hidden)
                .listSectionSpacing(8)
            }

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
        .refreshable {
            viewModel.handle(.refreshFeed)
        }
    }

    private var emptyStateView: some View {
        ResonanceEmptyView(
            title: "Уведомлений пока нет 👀 🔔",
            onRetryTap: {
                viewModel.handle(.refreshFeed)
            }
        )
    }
}
