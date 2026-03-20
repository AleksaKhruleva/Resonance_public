import SwiftUI
import UIComponents
import Core

struct SearchView: View {

    @State private var viewModel: SearchViewModel
    @FocusState private var isQueryFocused: Bool

    var textFieldPlaceholder: String {
        viewModel.selectedScope.textFieldPlaceholder
    }

    init(onUserTap: ((String) -> Void)?) {
        _viewModel = State(initialValue: SearchViewModel(onUserTap: onUserTap))
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            VStack(spacing: 16) {
                textField
                    .padding(.horizontal, AppSize.horizontalPadding)

                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitle("Поиск")
        .simultaneousGesture(
            TapGesture().onEnded {
                isQueryFocused = false
            }
        )
        .toast(
            viewModel.toast,
            onTap: {
                viewModel.handle(.dismissToast)
            }
        )
    }

    private var textField: some View {
        TextField(
            textFieldPlaceholder,
            text: Binding(
                get: { viewModel.query },
                set: { viewModel.handle(.updateQuery($0)) }
            )
        )
        .font(.system(size: AppFontSize.body, weight: .medium))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .focused($isQueryFocused)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColor.placeholder.opacity(0.1))
        )
        .onSubmit {
            viewModel.handle(.submitSearch)
        }
    }

    @ViewBuilder
    private var content: some View {
        usersScopeContent
    }

    @ViewBuilder
    private var usersScopeContent: some View {
        switch viewModel.state {
        case .idle:
            idleStateView
        case .loading:
            loadingStateView
        case .loadingNextBatch, .content:
            usersResultList
        case .empty:
            emptyStateView
        case .error(let description):
            ErrorView(
                description: description,
                onRetryTap: {
                    viewModel.handle(.submitSearch)
                }
            )
        }
    }

    @ViewBuilder
    private var usersResultList: some View {
        List {
            ForEach(viewModel.foundUsers) { profile in
                UserProfileRow(
                    avatarData: profile.avatarData,
                    nick: profile.nick,
                    onTap: {
                        viewModel.handle(.openUserProfile(userNick: profile.nick))
                    }
                )
                .listRowBackground(Color.clear)
                .listRowInsets(.all, 0)
                .onAppear {
                    viewModel.handle(.loadNextUsersBatchIfNeeded(userId: profile.id))
                }
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
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
    }

    private var idleStateView: some View {
        Text("Начните поиск 🔍")
            .wixFont(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
    }

    private var loadingStateView: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
    }

    private var emptyStateView: some View {
        Text("Нет подходящих результатов 👀 🔍")
            .wixFont(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
    }
}
