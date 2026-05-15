import Foundation
import Networking

struct ReportTarget: Identifiable, Equatable {
    let type: ReportContentType
    let contentId: Int

    var id: String { "\(type.rawValue)-\(contentId)" }

    var title: String {
        switch type {
        case .question:
            return "Жалоба на вопрос"
        case .post:
            return "Жалоба на пост"
        case .answer:
            return "Жалоба на ответ"
        }
    }

    static func question(id: Int) -> ReportTarget {
        ReportTarget(type: .question, contentId: id)
    }

    static func post(id: Int) -> ReportTarget {
        ReportTarget(type: .post, contentId: id)
    }

    static func answer(id: Int) -> ReportTarget {
        ReportTarget(type: .answer, contentId: id)
    }

    private init(type: ReportContentType, contentId: Int) {
        self.type = type
        self.contentId = contentId
    }
}
