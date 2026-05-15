import SwiftUI
import UIComponents
import Core

struct ProfileQuestionsSectionView: View {

    private let minHeight: CGFloat
    private let availableWidth: CGFloat
    private let viewModel: ProfileQuestionsSectionViewModel

    @State private var questionPendingAnswer: Question?
    @State private var questionPendingDetailsAfterAnswerPublished: Question?
    @State private var reportTarget: ReportTarget?

    private var answerWidth: CGFloat {
        availableWidth / 7 * 5.5
    }

    init(
        viewModel: ProfileQuestionsSectionViewModel,
        minHeight: CGFloat,
        availableWidth: CGFloat
    ) {
        self.viewModel = viewModel
        self.minHeight = minHeight
        self.availableWidth = availableWidth
    }

    var body: some View {
        content
            .onAppear {
                viewModel.handle(.loadFeed)
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

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loadingFeed, .refreshingFeed:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: minHeight)
        case .loadingNextBatch, .content:
            questionsContent
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
    private var questionsContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.questions) { question in
                QuestionView(
                    question: question,
                    presentationMode: .feed,
                    onAuthorTap: nil,
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

                answersPreview(for: question)

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
        Text("Здесь пока нет вопросов 👀 ❓")
            .wixFont(.semibold)
            .frame(maxWidth: .infinity, minHeight: minHeight)
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
        .padding(.top, 8)
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
            onDeleteTap: {
                guard answer.isOwnedByCurrentUser else { return }
                viewModel.handle(.requestAnswerDeletion(answerId: answer.id))
            },
            onBestTap: {
                guard question.isOwnedByCurrentUser else { return }
                viewModel.handle(.toggleBestAnswer(questionId: question.id, answerId: answer.id))
            }
        )
        .frame(width: answerWidth)
        .padding(12)
        .background(AppColor.placeholder.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
