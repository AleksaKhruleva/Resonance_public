import Foundation

public struct NickValidator {
    
    public enum ValidationError: String {
        case tooShort = "Ник должен содержать минимум 3 символа."
        case tooLong = "Ник не должен превышать 20 символов."
        case invalidCharacters = "Разрешены только русские буквы, цифры и нижнее подчеркивание."
        case mustStartWithLetterOrDigit = "Ник должен начинаться с буквы или цифры."
        case mustEndWithLetterOrDigit = "Ник должен заканчиваться буквой или цифрой."
        case mustContainLetter = "Ник должен содержать хотя бы одну русскую букву."
    }
    
    private static let allowedChars = "абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ0123456789_"
    private static let russianLetters = "абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
    private static let lettersAndDigits = "абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ0123456789"
    
    public static func validate(_ nick: String) -> ValidationError? {
        let trimmed = nick.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.count < 3 { return .tooShort }
        if trimmed.count > 20 { return .tooLong }
        
        var hasRussian = false
        
        for char in trimmed {
            if !allowedChars.contains(char) {
                return .invalidCharacters
            }
            if russianLetters.contains(char) {
                hasRussian = true
            }
        }
        
        if !hasRussian {
            return .mustContainLetter
        }
        
        let firstChar = trimmed.first!
        if !lettersAndDigits.contains(firstChar) {
            return .mustStartWithLetterOrDigit
        }
        
        let lastChar = trimmed.last!
        if !lettersAndDigits.contains(lastChar) {
            return .mustEndWithLetterOrDigit
        }
        
        return nil
    }
}
