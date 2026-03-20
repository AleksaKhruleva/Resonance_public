import Foundation

public enum ToastMessage: Equatable {

    case nextBatchLoadFailed
    case refreshFailed
    case likeFailed
    case deletePostFailed
    case deleteQuestionFailed
    case deleteAnswerFailed
    case markBestAnswerFailed
    case subscribeFailed
    case unsubscribeFailed
    case postPublishingFailed
    case questionPublishingFailed
    case answerPublishingFailed
    case reportSent
    case reportSendingFailed

    public var text: String {
        switch self {
        case .nextBatchLoadFailed:
            return "Не удалось загрузить новые данные"

        case .refreshFailed:
            return "Не удалось обновить данные"

        case .likeFailed:
            return "Не удалось поставить лайк"

        case .deletePostFailed:
            return "Не удалось удалить пост"

        case .deleteQuestionFailed:
            return "Не удалось удалить вопрос"

        case .deleteAnswerFailed:
            return "Не удалось удалить ответ"

        case .markBestAnswerFailed:
            return "Не удалось обновить лучший ответ"

        case .subscribeFailed:
            return "Не удалось подписаться"

        case .unsubscribeFailed:
            return "Не удалось отписаться"

        case .postPublishingFailed:
            return "Не удалось опубликовать пост"

        case .questionPublishingFailed:
            return "Не удалось опубликовать вопрос"

        case .answerPublishingFailed:
            return "Не удалось опубликовать ответ"

        case .reportSent:
            return "Жалоба отправлена"

        case .reportSendingFailed:
            return "Не удалось отправить жалобу"
        }
    }

    public var kind: ToastKind {
        switch self {
        case .reportSent:
            return .success
        default:
            return .error
        }
    }

    public var position: ToastPosition {
        .bottom
    }

    public var item: ToastItem {
        ToastItem(
            message: text,
            kind: kind,
            position: position
        )
    }
}
