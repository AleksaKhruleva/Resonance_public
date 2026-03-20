import SwiftUI
import UIComponents
import Core

struct CreateView: View {

    @State private var viewModel: CreateViewModel

    init(
        onPostPublished: (() -> Void)? = nil,
        onQuestionPublished: (() -> Void)? = nil
    ) {
        _viewModel = State(
            initialValue: CreateViewModel(
                onPostPublished: onPostPublished,
                onQuestionPublished: onQuestionPublished
            )
        )
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            VStack(spacing: 16) {
                Picker(
                    "",
                    selection: Binding(
                        get: { viewModel.selectedContentType },
                        set: { viewModel.handle(.selectContent($0)) }
                    )
                ) {
                    ForEach(CreateViewModel.ContentType.allCases) { contentType in
                        Text(contentType.rawValue)
                            .tag(contentType)
                    }
                }
                .pickerStyle(.segmented)

                switch viewModel.selectedContentType {
                case .post:
                    CreatePostView(viewModel: viewModel)
                case .question:
                    CreateQuestionView(viewModel: viewModel)
                }
            }
            .padding(.horizontal, AppSize.horizontalPadding)
        }
        .toast(
            viewModel.toast,
            onTap: {
                viewModel.handle(.dismissToast)
            }
        )
        .toolbarTitleDisplayMode(.inline)
        .toolbarTitle("Создать что-то новое")
    }
}
