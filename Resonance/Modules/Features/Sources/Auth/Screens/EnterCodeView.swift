import SwiftUI
import UIComponents

struct EnterCodeView: View {

    private let onContinue: (AuthFlow, String?) -> Void

    @State private var viewModel: EnterCodeViewModel
    @FocusState private var fieldIsFocused: Bool
    
    init(
        authFlow: AuthFlow,
        accessToken: String,
        email: String,
        onContinue: @escaping (AuthFlow, String?) -> Void
    ) {
        _viewModel = State(initialValue: EnterCodeViewModel(authFlow: authFlow, accessToken: accessToken, email: email))
        self.onContinue = onContinue
    }
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            
            VStack(spacing: 32) {
                Text("Введите код\nподтверждения")
                    .wixFont(.bold, size: AppFontSize.title)
                    .multilineTextAlignment(.center)
                
                TextField("XXXXXX", text: $viewModel.code)
                    .wixFont()
                    .focused($fieldIsFocused)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .onChange(of: viewModel.code) { oldValue, newValue in
                        viewModel.handle(.updateCode(oldValue, newValue))
                    }
                
                Text(verbatim: "Код отправлен на\n\(viewModel.email)\nПроверьте папку Спам")
                    .wixFont(color: AppColor.placeholder)
                    .multilineTextAlignment(.center)
                
                Button {
                    viewModel.handle(.getNewCode)
                } label: {
                    Text(buttonTitle)
                        .wixFont(color: buttonColor)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                }
                .disabled(viewModel.secondsRemaining > 0)
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
                case .submittedCode:
                    fieldIsFocused = false
                case .enteredCorrectCode(let accessToken):
                    fieldIsFocused = false
                    onContinue(viewModel.authFlow, accessToken)
                case .signinCompleted:
                    fieldIsFocused = false
                    onContinue(viewModel.authFlow, nil)
            }
        }
        .task {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(120))
            fieldIsFocused = true
            viewModel.handle(.startTimer)
        }
    }
    
    private var buttonTitle: String {
        viewModel.secondsRemaining > 0 ? "Отправить код повторно\nможно через \(formattedTime)" : "Отправить код повторно\n"
    }
    
    private var buttonColor: Color {
        viewModel.secondsRemaining > 0 ? AppColor.placeholder : AppColor.blue
    }
    
    private var formattedTime: String {
        let minutes = viewModel.secondsRemaining / 60
        let seconds = viewModel.secondsRemaining % 60
        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}
