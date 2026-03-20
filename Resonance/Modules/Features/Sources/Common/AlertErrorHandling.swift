import Core

@MainActor
protocol AlertErrorHandling: AnyObject {
    
    var errorAlertTitle: String { get set }
    var errorAlertMessage: String { get set }
    var showErrorAlert: Bool { get set }
}

extension AlertErrorHandling {
    
    func showError(
        _ message: String = AlertStrings.errorMessage,
        withTitle title: String = AlertStrings.errorTitle
    ) {
        errorAlertTitle = title
        errorAlertMessage = message
        showErrorAlert = true
    }
}
