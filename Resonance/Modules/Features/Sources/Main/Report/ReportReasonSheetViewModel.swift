import Core
import Foundation
import Networking

@MainActor
@Observable
final class ReportReasonSheetViewModel {

    enum Intent {
        case updateText(String)
        case submit
        case dismissToast
    }

    enum State: Equatable {
        case idle
        case sending
        case sent
    }

    enum Limits {
        static let maxTextLength = 500
    }

    private(set) var state: State = .idle
    private(set) var toast: ToastItem?
    private(set) var text = ""

    private let target: ReportTarget
    private let reportService: ReportService

    var isReadyForSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        target: ReportTarget,
        reportService: ReportService = ReportService()
    ) {
        self.target = target
        self.reportService = reportService
    }

    func handle(_ intent: Intent) {
        switch intent {
        case .updateText(let text):
            self.text = String(text.prefix(Self.Limits.maxTextLength))
        case .submit:
            Task { await submitReport() }
        case .dismissToast:
            toast = nil
        }
    }

    private func submitReport() async {
        guard state != .sending, isReadyForSend else { return }

        state = .sending

        let result = await reportService.createReport(
            type: target.type,
            id: target.contentId,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        switch result {
        case .success:
            state = .sent
        case .failure:
            state = .idle
            toast = ToastItem(
                message: ToastMessage.reportSendingFailed.text,
                kind: ToastMessage.reportSendingFailed.kind,
                position: .top
            )
        }
    }
}
