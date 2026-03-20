import SwiftUI
import Core
import UIComponents

struct PostDetailedView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PostDetailedViewModel
    @State private var reportTarget: ReportTarget?
    @State private var reportToast: ToastItem?
    private let onPostDeleted: ((Post) -> Void)?

    init(
        post: Post,
        onPostDeleted: ((Post) -> Void)? = nil
    ) {
        self.onPostDeleted = onPostDeleted
        _viewModel = State(
            initialValue: PostDetailedViewModel(post: post)
        )
    }

    private var activeToast: ToastItem? {
        reportToast ?? viewModel.toast
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            List {
                PostView(
                    post: viewModel.post,
                    shouldDisableLikeButton: viewModel.isLikeLoading,
                    onAuthorTap: nil,
                    onLikeTap: {
                        viewModel.handle(.toggleLike)
                    },
                    onReportTap: {
                        reportTarget = .post(id: viewModel.post.id)
                    },
                    onDeleteTap: {
                        viewModel.handle(.requestPostDeletion)
                    }
                )
                .padding(.top, 4)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 24, trailing: 0))
            }
            .listStyle(.plain)
            .scrollIndicators(.never)
            .scrollContentBackground(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitle("Пост")
        .toolbar(.hidden, for: .tabBar)
        .loading(viewModel.state == .deleting)
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
        .alert(
            "Удалить пост?",
            isPresented: Binding(
                get: { viewModel.isDeleteConfirmationPresented },
                set: { isPresented in
                    guard !isPresented else { return }
                    viewModel.handle(.cancelPostDeletion)
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
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            onPostDeleted?(viewModel.post)
            NotificationCenter.default.post(
                name: .profilePostDeleted,
                object: nil,
                userInfo: [
                    ProfilePostDeletionNotification.authorNickKey: viewModel.post.authorNick
                ]
            )
            dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .postLikeChanged)) { notification in
            guard
                let postId = notification.userInfo?[PostLikeNotification.postIdKey] as? Int,
                let isLiked = notification.userInfo?[PostLikeNotification.isLikedKey] as? Bool,
                let likesCount = notification.userInfo?[PostLikeNotification.likesCountKey] as? Int
            else {
                return
            }

            viewModel.handle(
                .postLikeChanged(
                    postId: postId,
                    isLiked: isLiked,
                    likesCount: likesCount
                )
            )
        }
    }

    private func dismissActiveToast() {
        if reportToast != nil {
            reportToast = nil
        } else {
            viewModel.handle(.dismissToast)
        }
    }
}
