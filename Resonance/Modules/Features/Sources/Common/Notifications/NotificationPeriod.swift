import Foundation

struct NotificationSection: Identifiable {
    let period: NotificationPeriod
    let items: [NotificationItem]

    var id: NotificationPeriod { period }
    var title: String { period.title }
}

enum NotificationPeriod: CaseIterable, Hashable {
    case today
    case thisWeek
    case earlier

    init(date: Date) {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            self = .today
            return
        }

        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()), date >= weekAgo {
            self = .thisWeek
        } else {
            self = .earlier
        }
    }

    var title: String {
        switch self {
        case .today:
            return "Сегодня"
        case .thisWeek:
            return "На этой неделе"
        case .earlier:
            return "Ранее"
        }
    }
}
