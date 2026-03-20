import Foundation

public struct EmailValidator {
    
    public static func validate(_ email: String) -> String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedEmail.isEmpty {
            return "Вы не ввели почту."
        }
        
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if !predicate.evaluate(with: trimmedEmail) {
            return "Возможно, пропущен знак @ или точка в домене."
        }
        
        return nil
    }
}
