import SwiftUI
import Core
import UIComponents

struct CreateAddressedQuestionView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateAddressedQuestionViewModel

    private let recipient: UserProfile

    init(
        recipient: UserProfile,
        onQuestionPublished: (() -> Void)?
    ) {
        self.recipient = recipient
        _viewModel = State(
            initialValue: CreateAddressedQuestionViewModel(
                recipient: recipient,
                onQuestionPublished: onQuestionPublished
            )
        )
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    recipientSection
                    anonymitySection
                    contentFormatSection
                    switch viewModel.questionContentFormat {
                    case .text:
                        questionTextSection
                    case .audio:
                        audioSection
                    }
                    publishButton
                }
                .padding(.horizontal, AppSize.horizontalPadding)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.never)
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbarTitle("Задать вопрос")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Отмена") {
                    dismiss()
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

    private var recipientSection: some View {
        HStack(spacing: 8) {
            Text("Вопрос для")
                .foregroundStyle(AppColor.placeholder)

            AvatarView(imageData: recipient.avatarData, frame: 32)

            Text(recipient.nick)
                .fontWeight(.semibold)
        }
        .padding(.top, 4)
        .padding(.bottom, -4)
    }

    private var anonymitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Приватность вашего профиля")
                .fontSize(20, weight: .semibold)
            HStack(spacing: 12) {
                OptionButton(
                    iconName: "eye",
                    title: CreateViewModel.QuestionAuthorAnonymity.identified.rawValue,
                    isSelected: viewModel.questionAuthorAnonymity.isIdentified,
                    action: { viewModel.handle(.selectQuestionAuthorAnonymity(.identified)) }
                )
                OptionButton(
                    iconName: "eye.slash",
                    title: CreateViewModel.QuestionAuthorAnonymity.anonymous.rawValue,
                    isSelected: viewModel.questionAuthorAnonymity.isAnonymous,
                    action: { viewModel.handle(.selectQuestionAuthorAnonymity(.anonymous)) }
                )
            }
            Text(viewModel.questionAuthorAnonymity.explanation)
                .fontSize(AppFontSize.caption)
                .foregroundStyle(AppColor.placeholder)
        }
    }

    private var contentFormatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Формат вопроса")
                .fontSize(20, weight: .semibold)
            HStack(spacing: 12) {
                OptionButton(
                    iconName: "waveform",
                    title: CreateViewModel.QuestionContentFormat.audio.rawValue,
                    isSelected: viewModel.questionContentFormat.isAudio,
                    action: { selectFormat(.audio) }
                )
                OptionButton(
                    iconName: "text.bubble",
                    title: CreateViewModel.QuestionContentFormat.text.rawValue,
                    isSelected: viewModel.questionContentFormat.isText,
                    action: { selectFormat(.text) }
                )
            }
        }
    }

    private var questionTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                Text("Текст вопроса")
                    .fontSize(20, weight: .semibold)
                Spacer()
                Text(verbatim: "\(viewModel.questionText.count)/\(CreateViewModel.Limits.maxQuestionTextLength)")
                    .foregroundStyle(AppColor.placeholder)
                    .fontSize(AppFontSize.caption)
            }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColor.placeholder.opacity(0.1))
                if viewModel.questionText.isEmpty {
                    Text("Напишите вопрос...")
                        .foregroundStyle(AppColor.placeholder)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                TextEditor(
                    text: Binding(
                        get: { viewModel.questionText },
                        set: { viewModel.handle(.updateQuestionText($0)) }
                    )
                )
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.clear)
            }
            .frame(minHeight: 150)
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AudioDraftView(
                title: "Аудио вопроса",
                maxDuration: CreateViewModel.Limits.maxAudioDuration,
                initialRecordingFileURL: viewModel.questionAudioFileURL,
                initialRecordingDuration: viewModel.questionAudioDuration,
                onPrepareForRecording: {},
                onRecordingCreated: handleAudioCreated,
                onRecordingDeleted: handleAudioDeleted
            )
            .id(viewModel.questionAudioDraftId)
            transcriptionView
        }
    }

    @ViewBuilder
    private var transcriptionView: some View {
        switch viewModel.questionTranscriptionState {
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
            viewModel.handle(.submitQuestion)
        } label: {
            Text("Отправить")
                .wixFont(.bold, color: AppColor.lightText)
                .frame(maxWidth: .infinity)
                .frame(height: AppSize.controlHeight)
                .opacity(viewModel.isQuestionReadyForPublish ? 1 : 0.4)
        }
        .background(Capsule().fill(AppColor.blue))
        .padding(.bottom, 20)
        .disabled(!viewModel.isQuestionReadyForPublish || viewModel.state == .publishing)
    }

    private func selectFormat(_ format: CreateViewModel.QuestionContentFormat) {
        viewModel.handle(.selectQuestionFormat(format))
    }

    private func handleAudioCreated(fileURL: URL, duration: TimeInterval) {
        viewModel.handle(.finishQuestionAudioRecording(fileURL: fileURL, duration: duration))
    }

    private func handleAudioDeleted() {
        viewModel.handle(.deleteQuestionAudio)
    }
}
