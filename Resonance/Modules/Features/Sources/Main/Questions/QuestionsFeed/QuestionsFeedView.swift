import SwiftUI
import UIComponents
import Core

struct QuestionsFeedView: View {

    @State private var viewModel: QuestionsFeedViewModel
    @State private var viewSize: CGSize = .zero
    @State private var questionPendingAnswer: Question?
    @State private var questionPendingDetailsAfterAnswerPublished: Question?
    @State private var reportTarget: ReportTarget?
    @Binding private var refreshTrigger: Int
    @Binding private var refreshFilter: FeedFilter?

    private var availableWidth: CGFloat {
        max(0, viewSize.width - AppSize.horizontalPadding * 2)
    }

    private var answerWidth: CGFloat {
        availableWidth / 7 * 5.5
    }

    init(
        refreshTrigger: Binding<Int> = .constant(0),
        refreshFilter: Binding<FeedFilter?> = .constant(nil),
        onAuthorTap: ((String) -> Void)?,
        onQuestionTap: ((Question) -> Void)?,
        onNotificationsTap: (() -> Void)?
    ) {
        _refreshTrigger = refreshTrigger
        _refreshFilter = refreshFilter
        _viewModel = State(
            initialValue: QuestionsFeedViewModel(
                onAuthorTap: onAuthorTap,
                onQuestionTap: onQuestionTap,
                onNotificationsTap: onNotificationsTap
            )
        )
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            content
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitle(viewModel.selectedFilter.navigationBarTitle)
        .toolbar { toolbarButtons }
        .loading(viewModel.state == .loadingFeed || viewModel.state == .refreshingFeed)
        .toast(
            viewModel.toast,
            onTap: {
                viewModel.handle(.dismissToast)
            }
        )
        .background(Color.clear.readSize($viewSize))
        .onAppear {
            viewModel.handle(.loadFeed)
            handleRefreshTrigger()
        }
        .onChange(of: refreshTrigger) { _, _ in
            handleRefreshTrigger()
        }
        .sheet(item: $questionPendingAnswer) { question in
            NavigationStack {
                CreateAnswerView(
                    question: question,
                    onPublished: {
                        viewModel.handle(.answerPublished(questionId: question.id))
                        questionPendingDetailsAfterAnswerPublished = question
                    }
                )
            }
        }
        .onChange(of: questionPendingAnswer) { _, question in
            guard question == nil, let answeredQuestion = questionPendingDetailsAfterAnswerPublished else {
                return
            }

            questionPendingDetailsAfterAnswerPublished = nil
            viewModel.handle(.openQuestionDetails(question: answeredQuestion))
        }
        .sheet(item: $reportTarget) { target in
            ReportReasonSheetView(
                target: target,
                onSent: {
                    viewModel.handle(.reportSent)
                }
            )
        }
        .alert(
            "Удалить вопрос?",
            isPresented: Binding(
                get: { viewModel.isDeleteConfirmationPresented },
                set: { isPresented in
                    guard !isPresented else { return }
                    viewModel.handle(.dismissQuestionDeletion)
                }
            )
        ) {
            Button("Отмена", role: .cancel) {
                viewModel.handle(.cancelQuestionDeletion)
            }
            Button("Удалить", role: .destructive) {
                viewModel.handle(.confirmQuestionDeletion)
            }
        } message: {
            Text("Это действие нельзя отменить.")
        }
        .alert(
            "Удалить ответ?",
            isPresented: Binding(
                get: { viewModel.isAnswerDeleteConfirmationPresented },
                set: { isPresented in
                    guard !isPresented else { return }
                    viewModel.handle(.dismissAnswerDeletion)
                }
            )
        ) {
            Button("Отмена", role: .cancel) {
                viewModel.handle(.cancelAnswerDeletion)
            }
            Button("Удалить", role: .destructive) {
                viewModel.handle(.confirmAnswerDeletion)
            }
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                ForEach(FeedFilter.allCases, id: \.self) { filter in
                    Button {
                        viewModel.handle(.selectFilter(filter))
                    } label: {
                        if viewModel.selectedFilter == filter {
                            Label(filter.title, systemImage: "checkmark")
                        } else {
                            Text(filter.title)
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .fontWeight(.semibold)
            }
        }

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
            questionsList
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

    private var questionsList: some View {
        List {
            ForEach(viewModel.questions) { question in
                VStack(spacing: 0) {
                    questionCard(question)
                    answersPreview(for: question)
                }
                .onAppear {
                    viewModel.handle(.loadNextBatchIfNeeded(questionId: question.id))
                }
            }
            .listRowBackground(Color.clear)
            .listSectionSeparator(.hidden)
            .listRowInsets(.all, AppSize.horizontalPadding)

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
            title: "Здесь пока нет вопросов 👀 ❓",
            onRetryTap:  {
                viewModel.handle(.refreshFeed)
            }
        )
    }

    private func handleRefreshTrigger() {
        viewModel.handle(
            .refreshFeedIfNeeded(
                trigger: refreshTrigger,
                filter: refreshFilter
            )
        )
        refreshFilter = nil
    }

    private func questionCard(_ question: Question) -> some View {
        QuestionView(
            question: question,
            presentationMode: .feed,
            onAuthorTap: {
                viewModel.handle(.openUserProfile(userNick: question.authorNick))
            },
            onRecipientTap: { recipientNick in
                viewModel.handle(.openUserProfile(userNick: recipientNick))
            },
            onDetailsTap: {
                viewModel.handle(.openQuestionDetails(question: question))
            },
            onAnswerTap: {
                questionPendingAnswer = question
            },
            onReportTap: {
                reportTarget = .question(id: question.id)
            },
            onDeleteTap: {
                viewModel.handle(.requestQuestionDeletion(questionId: question.id))
            },
            animatesTextExpansion: false
        )
    }

    private func answersPreview(for question: Question) -> some View {
        let previewAnswers = QuestionAnswerPreview.limitedAnswers(question.answers)

        return TrailingFadeHorizontalScrollView(
            itemsCount: previewAnswers.count,
            itemWidth: answerWidth,
            availableScreenWidth: availableWidth
        ) {
            ForEach(previewAnswers) { answer in
                answerCard(question: question, answer: answer)
            }
        }
        .padding(.top, question.answersCount > 0 ? 8 : 0)
    }

    private func answerCard(question: Question, answer: Answer) -> some View {
        AnswerView(
            answer: answer,
            presentationMode: .feed,
            shouldDisableLikeButton: viewModel.shouldDisableAnswerActions(
                questionId: question.id,
                answerId: answer.id
            ),
            onAuthorTap: {
                viewModel.handle(.openUserProfile(userNick: answer.authorNick))
            },
            onLikeTap: {
                viewModel.handle(.toggleAnswerLike(answerId: answer.id))
            },
            onReportTap: {
                reportTarget = .answer(id: answer.id)
            },
            onDeleteTap: answerDeleteAction(for: answer),
            onBestTap: bestAnswerAction(for: question, answer: answer)
        )
        .frame(width: answerWidth)
        .padding(12)
        .background(AppColor.placeholder.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func answerDeleteAction(for answer: Answer) -> (() -> Void)? {
        guard answer.isOwnedByCurrentUser else { return nil }
        return {
            viewModel.handle(.requestAnswerDeletion(answerId: answer.id))
        }
    }

    private func bestAnswerAction(for question: Question, answer: Answer) -> (() -> Void)? {
        guard question.isOwnedByCurrentUser else { return nil }
        return {
            viewModel.handle(.toggleBestAnswer(questionId: question.id, answerId: answer.id))
        }
    }
}
