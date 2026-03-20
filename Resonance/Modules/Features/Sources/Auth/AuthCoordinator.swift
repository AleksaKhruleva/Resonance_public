import SwiftUI

enum AuthFlow {
    case signin
    case signup
}

public struct AuthCoordinator: View {

    private let onFinishAuth: () -> Void

    @State private var path = NavigationPath()
    
    public init(onFinishAuth: @escaping () -> Void) {
        self.onFinishAuth = onFinishAuth
    }
    
    @ViewBuilder
    private func destination(for route: AuthRoute) -> some View {
        switch route {
            case .enterEmail(let authFlow):
                EnterEmailView(authFlow: authFlow) { authFlow, accessToken, email  in
                    path.append(AuthRoute.enterCode(authFlow: authFlow, accessToken: accessToken, email: email))
                }
                
            case .enterCode(let authFlow, let accessToken, let email):
                EnterCodeView(authFlow: authFlow, accessToken: accessToken, email: email) { authFlow, accessToken in
                    switch authFlow {
                        case .signin:
                            onFinishAuth()
                        case .signup:
                            guard let accessToken else {
                                // Show error somehow
                                return
                            }
                            path.append(AuthRoute.enterNick(accessToken: accessToken, email: email))
                    }
                }
                
            case .enterNick(let accessToken, let email):
                EnterNickView(accessToken: accessToken, email: email) {
                    onFinishAuth()
                }
        }
    }
    
    public var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                onSignin: {
                    path.append(AuthRoute.enterEmail(authFlow: .signin))
                },
                onSignup: {
                    path.append(AuthRoute.enterEmail(authFlow: .signup))
                })
            .navigationDestination(for: AuthRoute.self) { route in
                destination(for: route)
            }
        }
    }
}
