import SwiftUI
import UIComponents

struct WelcomeView: View {
    
    private let onSignin: () -> Void
    private let onSignup: () -> Void
    
    init(
        onSignin: @escaping () -> Void,
        onSignup: @escaping () -> Void
    ) {
        self.onSignin = onSignin
        self.onSignup = onSignup
    }
    
    var body: some View {
        ZStack {
            AppBackgroundView()
            
            VStack {
                Spacer()
                
                Text("Resonance")
                    .playfairFont(size: AppFontSize.appName)
                    .padding(.bottom, 1)
                
                Text("Найди свою частоту")
                    .wixFont()
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button {
                    onSignin()
                } label: {
                    Text("Войти")
                        .wixFont(color: AppColor.background)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(.glassProminent)
                .tint(AppColor.blue)
                
                Button {
                    onSignup()
                } label: {
                    Text("Создать аккаунт")
                        .wixFont(color: AppColor.blue)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
        }
    }
}
