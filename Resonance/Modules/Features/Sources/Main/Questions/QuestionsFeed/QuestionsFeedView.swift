import SwiftUI
import UIComponents
import Core

struct QuestionsFeedView: View {

    private static let answerPreviewLimit = 3

    @State private var viewModel: QuestionsFeedViewModel
    @State private var viewSize: CGSize = .zero
    @State private var questionPendingAnswer: Question?
    @State private var questionPendingDetailsAfterAnswerPublished: Question?
    @State private var reportTarget: ReportTarget?
    @State private var reportToast: ToastItem?
    @Binding private var refreshTrigger: Int
    @Binding private var refreshFilter: QuestionsFeedViewModel.FeedFilter?

    private var availableWidth: CGFloat {
        max(0, viewSize.width - AppSize.horizontalPadding * 2)
    }

    private var answerWidth: CGFloat {
        availableWidth / 7 * 5.5
    }

    private var activeToast: ToastItem? {
        reportToast ?? viewModel.toast
    }

    init(
        refreshTrigger: Binding<Int> = .constant(0),
        refreshFilter: Binding<QuestionsFeedViewModel.FeedFilter?> = .constant(nil),
        onAuthorTap: ((String) -> Void)?,
        onQuestionTap: ((Question) -> Void)?,
        onNotificationsTap: (() -> Void)? = nil
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
            activeToast,
            onTap: {
                dismissActiveToast()
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
        .onReceive(NotificationCenter.default.publisher(for: .questionDeleted)) { notification in
            guard
                let questionId = notification.userInfo?[QuestionDeletionNotification.questionIdKey] as? Int
            else {
                return
            }
            viewModel.handle(.questionDeleted(questionId: questionId))
        }
        .sheet(item: $questionPendingAnswer) { question in
            NavigationStack {
                CreateAnswerView(
                    question: question,
                    onPublished: {
                        notifyAnswerPublished(questionId: question.id)
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
                    reportToast = ToastMessage.reportSent.item
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .answerDeleted)) { notification in
            guard
                let answerId = notification.userInfo?[AnswerDeletionNotification.answerIdKey] as? Int
            else {
                return
            }
            viewModel.handle(.answerDeleted(answerId: answerId))
        }
        .onReceive(NotificationCenter.default.publisher(for: .answerPublished)) { notification in
            guard
                let questionId = notification.userInfo?[AnswerPublishedNotification.questionIdKey] as? Int
            else {
                return
            }

            viewModel.handle(.answerPublished(questionId: questionId))
        }
        .onReceive(NotificationCenter.default.publisher(for: .answerLikeChanged)) { notification in
            guard
                let answerId = notification.userInfo?[AnswerLikeNotification.answerIdKey] as? Int,
                let isLiked = notification.userInfo?[AnswerLikeNotification.isLikedKey] as? Bool,
                let likesCount = notification.userInfo?[AnswerLikeNotification.likesCountKey] as? Int
            else {
                return
            }

            viewModel.handle(
                .answerLikeChanged(
                    answerId: answerId,
                    isLiked: isLiked,
                    likesCount: likesCount
                )
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .bestAnswerChanged)) { notification in
            guard
                let questionId = notification.userInfo?[BestAnswerNotification.questionIdKey] as? Int,
                let answerId = notification.userInfo?[BestAnswerNotification.answerIdKey] as? Int,
                let isBest = notification.userInfo?[BestAnswerNotification.isBestKey] as? Bool
            else {
                return
            }
            viewModel.handle(
                .bestAnswerChanged(
                    questionId: questionId,
                    answerId: answerId,
                    isBest: isBest
                )
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
                ForEach(QuestionsFeedViewModel.FeedFilter.allCases, id: \.self) { filter in
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
                let previewAnswers = Array(question.answers.prefix(Self.answerPreviewLimit))

                VStack(spacing: 0) {
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

                    TrailingFadeHorizontalScrollView(
                        itemsCount: previewAnswers.count,
                        itemWidth: answerWidth,
                        availableScreenWidth: availableWidth
                    ) {
                        ForEach(previewAnswers) { answer in
                            let onDeleteTap: (() -> Void)? = answer.isOwnedByCurrentUser
                                ? { viewModel.handle(.requestAnswerDeletion(answerId: answer.id)) }
                                : nil
                            let onBestTap: (() -> Void)? = question.isOwnedByCurrentUser
                                ? { viewModel.handle(.toggleBestAnswer(questionId: question.id, answerId: answer.id)) }
                                : nil
                            AnswerView(
                                answer: answer,
                                presentationMode: .feed,
                                shouldDisableLikeButton: viewModel.isAnswerLikeLoading(answerId: answer.id)
                                    || viewModel.isAnswerDeleting(answerId: answer.id)
                                    || viewModel.isBestAnswerUpdating(answerId: answer.id)
                                    || viewModel.isQuestionDeleting(questionId: question.id),
                                onAuthorTap: {
                                    viewModel.handle(.openUserProfile(userNick: answer.authorNick))
                                },
                                onLikeTap: {
                                    viewModel.handle(.toggleAnswerLike(answerId: answer.id))
                                },
                                onReportTap: {
                                    reportTarget = .answer(id: answer.id)
                                },
                                onDeleteTap: onDeleteTap,
                                onBestTap: onBestTap
                            )
                            .frame(width: answerWidth)
                            .padding(12)
                            .background(AppColor.placeholder.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .padding(.top, question.answersCount > 0 ? 8 : 0)
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

    private func dismissActiveToast() {
        if reportToast != nil {
            reportToast = nil
        } else {
            viewModel.handle(.dismissToast)
        }
    }

    private func notifyAnswerPublished(questionId: Int) {
        NotificationCenter.default.post(
            name: .answerPublished,
            object: nil,
            userInfo: [
                AnswerPublishedNotification.questionIdKey: questionId
            ]
        )
    }
}
