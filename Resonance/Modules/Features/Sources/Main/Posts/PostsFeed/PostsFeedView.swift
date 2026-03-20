import SwiftUI
import UIComponents
import Core

struct PostsFeedView: View {

    @State private var viewModel: PostsFeedViewModel
    @State private var reportTarget: ReportTarget?
    @State private var reportToast: ToastItem?
    @Binding private var refreshTrigger: Int

    private var activeToast: ToastItem? {
        reportToast ?? viewModel.toast
    }

    init(
        currentUser: CurrentUser,
        refreshTrigger: Binding<Int> = .constant(0),
        onAuthorTap: ((String) -> Void)?,
        onNotificationsTap: (() -> Void)? = nil
    ) {
        _refreshTrigger = refreshTrigger
        _viewModel = State(initialValue: PostsFeedViewModel(
            currentUser: currentUser,
            onAuthorTap: onAuthorTap,
            onNotificationsTap: onNotificationsTap
        ))
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            content
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitle("Лента постов")
        .toolbar { toolbarButton }
        .loading(viewModel.state == .loadingFeed || viewModel.state == .refreshingFeed)
        .toast(
            activeToast,
            onTap: {
                dismissActiveToast()
            }
        )
        .sheet(item: $reportTarget) { target in
            ReportReasonSheetView(
                target: target,
                onSent: {
                    reportToast = ToastMessage.reportSent.item
                }
            )
        }
        .onAppear {
            viewModel.handle(.refreshFeedIfNeeded(trigger: refreshTrigger))
            viewModel.handle(.loadFeed)
        }
        .onChange(of: refreshTrigger) { _, _ in
            viewModel.handle(.refreshFeedIfNeeded(trigger: refreshTrigger))
        }
        .alert(
            "Удалить пост?",
            isPresented: Binding(
                get: { viewModel.isDeleteConfirmationPresented },
                set: { isPresented in
                    guard !isPresented else { return }
                    viewModel.handle(.dismissPostDeletion)
                }
            )
        ) {
            Button("Отмена", role: .cancel) {
                viewModel.handle(.cancelPostDeletion)
            }
            Button("Удалить", role: .destructive) {
                viewModel.handle(.confirmPostDeletion)
            }
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.handle(.openNotifications)
            } label: {
                Image(systemName: "bell")
                    .fontWeight(.semibold)
            }
            .disabled(!(viewModel.state == .content || viewModel.state == .empty))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loadingFeed:
            EmptyView()
        case .loadingNextBatch, .refreshingFeed, .content:
            postsContent
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

    private var postsContent: some View {
        List {
            ForEach(viewModel.posts) { post in
                PostView(
                    post: post,
                    shouldDisableLikeButton: viewModel.isLikeLoading(postId: post.id)
                        || viewModel.isPostDeleting(postId: post.id),
                    onAuthorTap: {
                        viewModel.handle(.openAuthorProfile(authorNick: post.authorNick))
                    },
                    onLikeTap: {
                        viewModel.handle(.toggleLike(postId: post.id))
                    },
                    onReportTap: {
                        reportTarget = .post(id: post.id)
                    },
                    onDeleteTap: {
                        viewModel.handle(.requestPostDeletion(postId: post.id))
                    }
                )
                .onAppear {
                    viewModel.handle(.loadNextBatchIfNeeded(postId: post.id))
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 24, trailing: 0))

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
            title: "Здесь пока нет постов 👀 🏞️",
            onRetryTap: {
                viewModel.handle(.refreshFeed)
            }
        )
    }

    private func dismissActiveToast() {
        if reportToast != nil {
            reportToast = nil
        } else {
            viewModel.handle(.dismissToast)
        }
    }
}
