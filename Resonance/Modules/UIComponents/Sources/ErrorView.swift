import SwiftUI

public struct ErrorView: View {

    private let description: String?
    private let onRetryTap: (() -> Void)?

    public init(
        description: String?,
        onRetryTap: (() -> Void)?
    ) {
        self.description = description
        self.onRetryTap = onRetryTap
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text("Не удалось загрузить данные :(")
                .wixFont(.semibold, size: 20)
                .multilineTextAlignment(.center)

            if let description {
                Text(description)
                    .foregroundStyle(AppColor.placeholder)
                    .multilineTextAlignment(.center)
            }

            Button {
                onRetryTap?()
            } label: {
                Text("Попробовать снова")
                    .wixFont(color: AppColor.lightText)
                    .padding(8)
            }
            .buttonStyle(.glassProminent)
            .padding(.top, 24)
        }
    }
}
