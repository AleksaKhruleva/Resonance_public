import SwiftUI

public struct MediaActionButton<Content: View>: View {

    private let shouldShowReportButton: Bool
    private let shouldShowDeleteButton: Bool
    private let onReportTap: (() -> Void)?
    private let onDeleteTap: (() -> Void)?
    private let menuContent: () -> Content

    public init(
        shouldShowReportButton: Bool,
        shouldShowDeleteButton: Bool,
        onReportTap: (() -> Void)? = nil,
        onDeleteTap: (() -> Void)? = nil,
        @ViewBuilder menuContent: @escaping () -> Content
    ) {
        self.shouldShowReportButton = shouldShowReportButton
        self.shouldShowDeleteButton = shouldShowDeleteButton
        self.onReportTap = onReportTap
        self.onDeleteTap = onDeleteTap
        self.menuContent = menuContent
    }

    public var body: some View {
        Menu {
            if shouldShowReportButton {
                reportButton
            }

            if shouldShowDeleteButton {
                deleteButton
            }

            menuContent()
        } label: {
            Image(systemName: "ellipsis")
                .fontSize(AppFontSize.caption, weight: .semibold)
                .frame(width: AppSize.reportButtonFrame, height: AppSize.reportButtonFrame)
                .contentShape(Circle())
        }
    }

    private var reportButton: some View {
        Button {
            onReportTap?()
        } label: {
            Label("Пожаловаться", systemImage: "exclamationmark.octagon")
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDeleteTap?()
        } label: {
            Label("Удалить", systemImage: "trash")
        }
    }
}
