import SwiftUI
import Core
import UIComponents

struct PostDetailedView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PostDetailedViewModel
    @State private var reportTarget: ReportTarget?

    init(post: Post) {
        _viewModel = State(
            initialValue: PostDetailedViewModel(post: post)
        )
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
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
                .padding(.bottom, 24)
            }
            .scrollIndicators(.never)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitle("Пост")
        .toolbar(.hidden, for: .tabBar)
        .loading(viewModel.state == .deleting)
        .toast(
            viewModel.toast,
            onTap: {
                viewModel.handle(.dismissToast)
            }
        )
        .sheet(item: $reportTarget) { target in
            ReportReasonSheetView(
                target: target,
                onSent: {
                    viewModel.handle(.reportSent)
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
            dismiss()
        }
    }
}
