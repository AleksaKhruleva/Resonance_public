import SwiftUI
import UIComponents
import Core

struct ProfilePostsSectionView: View {

    private struct Constants {
        static let spacing = 1.5
    }

    private let columns = [
        GridItem(.flexible(), spacing: Constants.spacing),
        GridItem(.flexible(), spacing: Constants.spacing),
        GridItem(.flexible(), spacing: Constants.spacing)
    ]

    private let minHeight: CGFloat
    private let viewModel: ProfilePostsSectionViewModel

    init(
        viewModel: ProfilePostsSectionViewModel,
        minHeight: CGFloat
    ) {
        self.viewModel = viewModel
        self.minHeight = minHeight
    }

    var body: some View {
        content
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
        case .loadingFeed, .refreshingFeed:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: minHeight)
        case .loadingNextBatch, .content:
            gridContent
        case .empty:
            emptyStateView
        case .error(let description):
            ErrorView(
                description: description,
                onRetryTap: {
                    viewModel.handle(.loadFeed)
                }
            )
            .frame(maxWidth: .infinity, minHeight: minHeight)
        }
    }
    
    @ViewBuilder
    private var gridContent: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: Constants.spacing) {
                ForEach(viewModel.posts) { post in
                    Button {
                        viewModel.handle(.openPostDetails(post: post))
                    } label: {
                        Image(data: post.imageData)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .clipped()
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        viewModel.handle(.loadNextBatchIfNeeded(postId: post.id))
                    }
                }
            }

            if viewModel.state == .loadingNextBatch {
                BatchLoadingView()
                    .id(UUID())
            }
        }
    }

    private var emptyStateView: some View {
        Text("Здесь пока нет постов 👀 🏞️")
            .wixFont(.semibold)
            .frame(maxWidth: .infinity, minHeight: minHeight)
    }
}
