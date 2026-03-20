import Foundation

public enum PublicationDateFormatter {

    public static func date(from serverDateString: String) -> Date? {
        serverDateFormatter.date(from: serverDateString)
    }

    public static func beautifulDate(from serverDateString: String, now: Date = Date()) -> String {
        guard let date = serverDateFormatter.date(from: serverDateString) else {
            return serverDateString
        }

        return string(from: date, now: now)
    }

    private static let serverDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static func string(from date: Date, now: Date = Date()) -> String {
        let seconds = Int(now.timeIntervalSince(date))

        if seconds < 60 {
            return "только что"
        }

        if seconds < 3600 {
            let minutes = max(1, seconds / 60)
            return "\(minutes) мин. назад"
        }

        if seconds < 24 * 60 * 60 {
            let hours = max(1, seconds / 3600)
            return "\(hours) ч. назад"
        }

        let days = Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0
        if days < 30 {
            return "\(max(1, days)) д. назад"
        }

        let weeks = max(1, days / 7)
        return "\(weeks) нед. назад"
    }
}
