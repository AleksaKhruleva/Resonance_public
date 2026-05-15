import Networking

enum FeedFilter: CaseIterable, Hashable {

    case all
    case following
    case outgoing
    case incoming

    var title: String {
        switch self {
        case .all:
            return "Общая лента"
        case .following:
            return "Персональная лента"
        case .outgoing:
            return "Исходящие вопросы"
        case .incoming:
            return "Входящие вопросы"
        }
    }

    var navigationBarTitle: String {
        switch self {
        case .all:
            return "Общая лента"
        case .following:
            return "Персональная лента"
        case .outgoing:
            return "Вопросы от Вас"
        case .incoming:
            return "Вопросы для Вас"
        }
    }

    var mode: QuestionsFeedMode {
        switch self {
        case .all:
            return .all
        case .following:
            return .following
        case .outgoing:
            return .outgoing
        case .incoming:
            return .incoming
        }
    }
}
