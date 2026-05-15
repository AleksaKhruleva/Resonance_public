import SwiftUI
import Networking
import Core
import UIComponents

struct ProfileAnswersSectionView: View {

    private let minHeight: CGFloat
    private let availableWidth: CGFloat
    private let viewModel: ProfileAnswersSectionViewModel
    @State private var questionPendingAnswer: Question?
    @State private var questionPendingDetailsAfterAnswerPublished: Question?
    @State private var reportTarget: ReportTarget?
    @State private var reportToast: ToastItem?

    private var answerWidth: CGFloat {
        availableWidth / 7 * 5.5
    }

    private var activeToast: ToastItem? {
        reportToast ?? viewModel.toast
    }

    init(
        viewModel: ProfileAnswersSectionViewModel,
        minHeight: CGFloat,
        availableWidth: CGFloat
    ) {
        self.viewModel = viewModel
        self.minHeight = minHeight
        self.availableWidth = availableWidth
    }

    var body: some View {
        content
            .toast(
                activeToast,
                onTap: {
                    dismissActiveToast()
                }
            )
            .onAppear {
                viewModel.handle(.loadFeed)
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

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loadingFeed, .refreshingFeed:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: minHeight)
        case .loadingNextBatch, .content:
            answersContent
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

    private var answersContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.questions) { question in
                let previewAnswers = QuestionAnswerPreview.limitedAnswers(question.answers)

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
                    }
                )
                .onAppear {
                    viewModel.handle(.loadNextBatchIfNeeded(questionId: question.id))
                }

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
                            onAuthorTap: nil,
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
                .padding(.top, 8)

                if question != viewModel.questions.last {
                    Divider()
                        .padding(.vertical, 12)
                } else {
                    Spacer(minLength: 16)
                }
            }
            if viewModel.state == .loadingNextBatch {
                BatchLoadingView()
                    .id(UUID())
            }
        }
        .padding(.horizontal, AppSize.horizontalPadding)
    }

    private var emptyStateView: some View {
        Text("Здесь пока нет ответов 👀 🗣️")
            .wixFont(.semibold)
            .frame(maxWidth: .infinity, minHeight: minHeight)
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
