import SwiftUI
import UIComponents
import Core

struct EnterEmailView: View {

    private let onContinue: (AuthFlow, String, String) -> Void

    @State private var viewModel: EnterEmailViewModel
    @FocusState private var fieldIsFocused: Bool
    
    init(
        authFlow: AuthFlow,
        onContinue: @escaping (AuthFlow, String, String) -> Void
    ) {
        _viewModel = State(initialValue: EnterEmailViewModel(authFlow: authFlow))
        self.onContinue = onContinue
    }
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            
            VStack(spacing: 32) {
                Spacer()
                
                Text("Укажите вашу почту")
                    .wixFont(.bold, size: AppFontSize.title)
                    .multilineTextAlignment(.center)
                
                TextField(
                    "",
                    text: $viewModel.email,
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
                .onChange(of: viewModel.email) { _, newValue in
                    viewModel.handle(.updateEmail(newValue))
                }
                .onSubmit {
                    viewModel.handle(.submitEmail)
                }
                
                Text("На эту почту будет отправлен\nкод подтверждения")
                    .wixFont(color: AppColor.placeholder)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button {
                    fieldIsFocused = false
                    viewModel.handle(.submitEmail)
                } label: {
                    Text("Продолжить")
                        .wixFont(color: AppColor.background)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.glassProminent)
                .tint(AppColor.blue)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .loading(viewModel.isLoading)
        .alert(viewModel.errorAlertTitle, isPresented: $viewModel.showErrorAlert) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(viewModel.errorAlertMessage)
        }
        .alert(viewModel.informationAlertTitle, isPresented: $viewModel.showInformationAlert) {
            Button("Отмена", role: .cancel) {}
            Button(viewModel.informationAlertMainAction) {
                viewModel.handle(.retryWithAnotherFlow)
            }
            .keyboardShortcut(.defaultAction)
        } message: {
            Text(viewModel.informationAlertMessage)
        }
        .task(id: viewModel.event) {
            guard let event = viewModel.consumeEvent() else { return }
            switch event {
                case .submittedEmail(let email, let accessToken):
                    onContinue(viewModel.authFlow, accessToken, email)
            }
        }
        .task {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(120))
            fieldIsFocused = true
        }
    }
}
