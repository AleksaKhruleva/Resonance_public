import SwiftUI
import Core
import UIComponents

struct CreateAnswerView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateAnswerViewModel

    init(
        question: Question,
        onPublished: (() -> Void)? = nil
    ) {
        _viewModel = State(
            initialValue: CreateAnswerViewModel(
                question: question,
                onPublished: onPublished
            )
        )
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    questionHintSection
                    visibilitySection
                    audioSection
                    publishButton
                }
                .padding(.horizontal, AppSize.horizontalPadding)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.never)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitle("Ответ")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text("Отмена")
                        .fontWeight(.medium)
                }
                .disabled(viewModel.state == .publishing)
            }
        }
        .loading(viewModel.state == .publishing)
        .toast(
            viewModel.toast,
            onTap: {
                viewModel.handle(.dismissToast)
            }
        )
        .onChange(of: viewModel.state) { _, state in
            guard state == .published else { return }
            dismiss()
        }
    }

    private var visibilitySection: some View {
        Text("Ответ будет опубликован публично")
            .foregroundStyle(AppColor.placeholder)
            .padding(.bottom, -4)
    }

    private var questionHintSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Вопрос")
                .fontSize(20, weight: .semibold)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    AvatarView(imageData: viewModel.questionAuthorAvatarData)

                    Text(viewModel.questionAuthorDisplayName)
                        .fontWeight(.semibold)

                    PublicationDateView(
                        date: PublicationDateFormatter.beautifulDate(from: viewModel.question.publishDate)
                    )
                }

                Text(viewModel.question.text)
                    .foregroundStyle(AppColor.placeholder)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColor.placeholder.opacity(0.1))
            )
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AudioDraftView(
                title: "Аудио ответа",
                maxDuration: CreateAnswerViewModel.Limits.maxAudioDuration,
                onPrepareForRecording: {},
                onRecordingCreated: handleAudioCreated,
                onRecordingDeleted: handleAudioDeleted
            )
            .id(viewModel.audioDraftId)

            transcriptionView
        }
    }

    @ViewBuilder
    private var transcriptionView: some View {
        switch viewModel.transcriptionState {
        case .idle:
            EmptyView()
        case .transcribing:
            HStack(spacing: 10) {
                ProgressView()
                Text("Расшифровываем аудио...")
                    .foregroundStyle(AppColor.placeholder)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: AppSize.compactControlHeight, alignment: .leading)
            .background(Capsule().fill(AppColor.placeholder.opacity(0.1)))
        case .finished(let text):
            VStack(alignment: .leading, spacing: 4) {
                Text("Расшифровка")
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.text)

                Text(text)
                    .foregroundStyle(AppColor.placeholder)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(AppColor.placeholder.opacity(0.1)))
        case .failed:
            Text("Не удалось расшифровать аудио")
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.red)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: AppSize.compactControlHeight, alignment: .leading)
                .background(Capsule().fill(AppColor.red.opacity(0.1)))
        }
    }

    private var publishButton: some View {
        Button {
            viewModel.handle(.submitAnswer)
        } label: {
            Text("Опубликовать")
                .wixFont(.bold, color: AppColor.lightText)
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.controlHeight)
                .opacity(viewModel.isReadyForPublish ? 1 : 0.4)
        }
        .background(Capsule().fill(AppColor.blue))
        .padding(.bottom, 20)
        .disabled(!viewModel.isReadyForPublish || viewModel.state == .publishing)
    }

    private func handleAudioCreated(fileURL: URL, duration: TimeInterval) {
        viewModel.handle(.finishAudioRecording(fileURL: fileURL, duration: duration))
    }

    private func handleAudioDeleted() {
        viewModel.handle(.deleteAudio)
    }
}
