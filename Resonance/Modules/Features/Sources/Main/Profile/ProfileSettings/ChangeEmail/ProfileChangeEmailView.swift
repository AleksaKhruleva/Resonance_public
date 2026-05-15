import SwiftUI
import UIComponents
import Core

struct ChangeEmailView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ChangeEmailViewModel

    @State private var newEmail: String = ""
    @FocusState private var fieldIsFocused: Bool

    init(currentEmail: String) {
        _viewModel = State(initialValue: ChangeEmailViewModel(currentEmail: currentEmail))
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            VStack(spacing: 32) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Отмена")
                            .fontWeight(.medium)
                            .padding(4)
                    }
                    .buttonStyle(.glass)
                    .disabled(viewModel.state == .requestingVerificationCode)

                    Spacer()
                }

                Spacer()

                Text("Укажите новую почту")
                    .wixFont(.bold, size: AppFontSize.title)
                    .multilineTextAlignment(.center)

                TextField(
                    "",
                    text: $newEmail,
                    prompt: Text(verbatim: "example@yandex.ru").foregroundColor(AppColor.placeholder)
                )
                .wixFont()
                .focused($fieldIsFocused)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .replaceDisabled()
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .padding(.horizontal)
                .onChange(of: newEmail) { _, newValue in
                    newEmail = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .onSubmit {
                    viewModel.handle(.changeEmail(newEmail: newEmail))
                }

                Text("На эту почту будет отправлен\nкод подтверждения")
                    .wixFont(color: AppColor.placeholder)
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    fieldIsFocused = false
                    viewModel.handle(.changeEmail(newEmail: newEmail))
                } label: {
                    Text("Продолжить")
                        .wixFont(color: AppColor.background)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.blue)
                .padding(.bottom, 40)
                .disabled(newEmail.isEmpty || newEmail == viewModel.currentEmail)
            }
            .padding(.horizontal, 20)
        }
        .loading(viewModel.state == .requestingVerificationCode)
        .task {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(120))
            fieldIsFocused = true
        }
    }
}
