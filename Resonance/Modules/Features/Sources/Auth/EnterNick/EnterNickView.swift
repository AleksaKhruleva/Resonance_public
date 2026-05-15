import SwiftUI
import UIComponents

struct EnterNickView: View {

    private let onContinue: () -> Void

    @State private var nick: String = ""

    @State private var viewModel: EnterNickViewModel
    @FocusState private var fieldIsFocused: Bool
    
    init(
        accessToken: String,
        email: String,
        onContinue: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: EnterNickViewModel(accessToken: accessToken, email: email))
        self.onContinue = onContinue
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppBackgroundView()
                
                ScrollView {
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 32) {
                            
                            Text("Придумайте ник")
                                .wixFont(.bold, size: AppFontSize.title)
                                .multilineTextAlignment(.center)
                            
                            Text("Это имя будут видеть другие пользователи\nВы всегда сможете изменить его в настройках профиля")
                                .wixFont(color: AppColor.placeholder)
                                .multilineTextAlignment(.center)
                            
                            TextField("космонавт77", text: $nick)
                                .wixFont()
                                .focused($fieldIsFocused)
                                .keyboardType(.default)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .replaceDisabled()
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .onChange(of: nick) { _, newValue in
                                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    nick = trimmed.prefix(20).lowercased()
                                }
                                .onSubmit {
                                    viewModel.handle(.submitNick(nick: nick))
                                }
                            
                            VStack(spacing: 5) {
                                Text("Формат ника:")
                                
                                VStack(alignment: .leading) {
                                    HStack(alignment: .top) {
                                        Text("-")
                                        Text("от 3 до 20 символов")
                                    }
                                    HStack(alignment: .top) {
                                        Text("-")
                                        Text("только русские буквы, цифры и нижнее подчеркивание")
                                    }
                                    HStack(alignment: .top) {
                                        Text("-")
                                        Text("начинается и заканчивается буквой или цифрой")
                                    }
                                    HStack(alignment: .top) {
                                        Text("-")
                                        Text("содержит хотя бы одну букву")
                                    }
                                }
                            }
                            .wixFont(color: AppColor.placeholder)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                        
                        Button {
                            fieldIsFocused = false
                            viewModel.handle(.submitNick(nick: nick))
                        } label: {
                            Text("Создать аккаунт")
                                .wixFont(color: AppColor.background)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(AppColor.blue)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                    .frame(minHeight: geo.size.height)
                }
                .scrollIndicators(.never)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .alert(viewModel.errorAlertTitle, isPresented: $viewModel.showErrorAlert) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(viewModel.errorAlertMessage)
        }
        .task(id: viewModel.event) {
            guard let event = viewModel.consumeEvent() else { return }
            switch event {
                case .signupCompleted:
                    onContinue()
            }
        }
        .task {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(120))
            fieldIsFocused = true
        }
    }
}
