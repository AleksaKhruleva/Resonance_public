import SwiftUI

public struct ResonanceEmptyView: View {

    private let title: String
    private let onRetryTap: () -> Void

    public init(
        title: String,
        onRetryTap: @escaping () -> Void
    ) {
        self.title = title
        self.onRetryTap = onRetryTap
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .wixFont(.semibold)
                .multilineTextAlignment(.center)

            Button {
                onRetryTap()
            } label: {
                Text("Обновить")
                    .wixFont()
                    .padding(8)
            }
            .buttonStyle(.glass)
            .padding(.top, 24)
        }
    }
}
