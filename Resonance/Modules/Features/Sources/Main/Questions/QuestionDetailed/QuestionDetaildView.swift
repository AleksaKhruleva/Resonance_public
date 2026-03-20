import SwiftUI
import Core
import UIComponents

struct QuestionDetailedView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: QuestionDetailedViewModel
    @State private var questionPendingAnswer: Question?
    @State private var reportTarget: ReportTarget?
    @State private var reportToast: ToastItem?

    init(
        questionId: Int,
        onAuthorTap: ((String) -> Void)? = nil
    ) {
        _viewModel = State(
            wrappedValue: QuestionDetailedViewModel(
                questionId: questionId,
                onAuthorTap: onAuthorTap
            )
        )
    }

    private var activeToast: ToastItem? {
        reportToast ?? viewModel.toast
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            content
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitle("Вопрос")
        .toolbar(.hidden, for: .tabBar)
        .loading(viewModel.state == .loadingQuestion || viewModel.state == .refreshingQuestion || viewModel.state == .deleting)
        .toast(
            activeToast,
            onTap: {
                dismissActiveToast()
            }
        )
        .onAppear {
            viewModel.handle(.loadQuestion)
        }
        .sheet(item: $questionPendingAnswer) { question in
            NavigationStack {
                CreateAnswerView(
                    question: question,
                    onPublished: {
                        notifyAnswerPublished(questionId: question.id)
                    }
                )
            }
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
                    viewModel.handle(.cancelQuestionDeletion)
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
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss, let question = viewModel.question else { return }
            NotificationCenter.default.post(
                name: .questionDeleted,
                object: nil,
                userInfo: [
                    QuestionDeletionNotification.questionIdKey: question.id,
                    QuestionDeletionNotification.authorNickKey: question.authorNick
                ]
            )
            dismiss()
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
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loadingQuestion, .deleting:
            EmptyView()
        case .loadingNextBatch, .refreshingQuestion, .content:
            questionContent
        case .error(let description):
            ErrorView(
                description: description,
                onRetryTap: {
                    viewModel.handle(.loadQuestion)
                }
            )
        }
    }

    @ViewBuilder
    private var questionContent: some View {
        if let question = viewModel.question {
            List {
                QuestionView(
                    question: question,
                    presentationMode: .details,
                    onAuthorTap: {
                        viewModel.handle(.openUserProfile(userNick: question.authorNick))
                    },
                    onRecipientTap: { recipientNick in
                        viewModel.handle(.openUserProfile(userNick: recipientNick))
                    },
                    onAnswerTap: {
                        questionPendingAnswer = question
                    },
                    onReportTap: {
                        reportTarget = .question(id: question.id)
                    },
                    onDeleteTap: {
                        viewModel.handle(.requestQuestionDeletion)
                    }
                )
                .listRowBackground(AppColor.placeholder.opacity(0.1))
                .listRowSeparator(.hidden)
                .listRowInsets(.all, AppSize.horizontalPadding)

                if question.answers.isEmpty {
                    emptyStateView
                        .padding(.top, 24)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(question.answers) { answer in
                        let onDeleteTap: (() -> Void)? = answer.isOwnedByCurrentUser
                            ? { viewModel.handle(.requestAnswerDeletion(answerId: answer.id)) }
                            : nil
                        let onBestTap: (() -> Void)? = question.isOwnedByCurrentUser
                            ? { viewModel.handle(.toggleBestAnswer(answerId: answer.id)) }
                            : nil
                        AnswerView(
                            answer: answer,
                            presentationMode: .details,
                            shouldDisableLikeButton: viewModel.isAnswerLikeLoading(answerId: answer.id)
                                || viewModel.isAnswerDeleting(answerId: answer.id)
                                || viewModel.isBestAnswerUpdating(answerId: answer.id),
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
                        .onAppear {
                            viewModel.handle(.loadNextBatchIfNeeded(answerId: answer.id))
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(.all, AppSize.horizontalPadding)
                        .listSectionSeparator(.hidden)
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
            .scrollContentBackground(.hidden)
            .refreshable {
                viewModel.handle(.refreshQuestion)
            }
        }
    }

    private var emptyStateView: some View {
        Text("Здесь пока нет ответов 👀 🗣️")
            .wixFont(.semibold)
            .frame(maxWidth: .infinity)
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
