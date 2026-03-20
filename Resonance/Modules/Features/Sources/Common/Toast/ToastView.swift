import SwiftUI
import Core
import UIComponents

public struct ToastView: View {

    private let item: ToastItem
    private let duration: Duration
    private let onDismiss: () -> Void

    public init(
        item: ToastItem,
        duration: Duration = .seconds(3),
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.duration = duration
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .fontWeight(.medium)

            Text(item.message)
                .fontSize(AppFontSize.caption, weight: .medium)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppColor.text.opacity(0.5), radius: 12, y: 4)
        .padding(16)
        .onTapGesture {
            onDismiss()
        }
        .task(id: item.id) {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                onDismiss()
            }
        }
    }

    private var iconName: String {
        switch item.kind {
        case .success:
            return "checkmark.circle"
        case .error:
            return "exclamationmark.circle"
        }
    }
}

#Preview {
    VStack {
        ToastView(
            item: ToastItem(
                message: "Удалось поставить лайк",
                kind: .success,
                position: .top
            ),
            onDismiss: {}
        )

        Color.clear.frame(height: 20)

        ToastView(
            item: ToastItem(
                message: "Не удалось поставить лайк",
                kind: .error,
                position: .bottom
            ),
            onDismiss: {}
        )
    }
    .frame(maxHeight: .infinity)
    .background(AppColor.background)
}
