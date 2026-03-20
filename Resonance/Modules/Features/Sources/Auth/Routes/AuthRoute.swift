
enum AuthRoute: Hashable {
    case enterEmail(authFlow: AuthFlow)
    case enterCode(authFlow: AuthFlow, accessToken: String, email: String)
    case enterNick(accessToken: String, email: String)
}
