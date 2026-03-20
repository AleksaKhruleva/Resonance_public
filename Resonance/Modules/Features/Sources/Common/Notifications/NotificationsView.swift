import SwiftUI
import Core
import UIComponents

struct NotificationsView: View {

    @State private var viewModel: NotificationsViewModel

    init(
        onUserTap: ((String) -> Void)? = nil,
        onQuestionTap: ((Int) -> Void)? = nil,
        onAnswerTap: ((Int, Int) -> Void)? = nil
    ) {
        _viewModel = State(
            initialValue: NotificationsViewModel(
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
            ForEach(sectionedNotifications) { section in
                Section {
                    ForEach(section.items) { item in
                        NotificationRow(
                            item: item,
                            onRowTap: {
                                viewModel.handle(.openNotification(item))
                            },
                            onAvatarTap: {
                                viewModel.handle(.openActorProfile(item))
                            }
                        )
                        .onAppear {
                            viewModel.handle(.loadNextBatchIfNeeded(noticeId: item.noticeId))
                        }
                    }
                } header: {
                    Text(section.title)
                        .wixFont(.bold, color: AppColor.placeholder, size: AppFontSize.caption)
                        .textCase(nil)
                        .padding(.top, -8)
                }
            }
            .listRowBackground(Color.clear)
            .listSectionSeparator(.hidden)
            .listRowInsets(.horizontal, AppSize.horizontalPadding)
            .listRowInsets(.vertical, 8)

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
        Text("Уведомлений пока нет 👀 🔔")
            .wixFont(.semibold)
    }

    private var sectionedNotifications: [NotificationSection] {
        let grouped = Dictionary(grouping: viewModel.notifications) { item in
            NotificationPeriod(date: item.createdAt)
        }

        return NotificationPeriod.allCases.compactMap { period in
            guard let items = grouped[period], !items.isEmpty else { return nil }
            return NotificationSection(
                period: period,
                items: items.sorted { $0.createdAt > $1.createdAt }
            )
        }
    }
}
