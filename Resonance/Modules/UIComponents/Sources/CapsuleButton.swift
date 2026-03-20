import SwiftUI

public struct CapsuleButton: View {

    private let systemImageName: String
    private let imageForegroundColor: Color
    private let title: String
    private let foregroundColor: Color
    private let action: () -> Void

    public init(
        systemImageName: String,
        title: String,
        foregroundColor: Color = AppColor.text,
        imageForegroundColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImageName = systemImageName
        self.imageForegroundColor = imageForegroundColor ?? foregroundColor
        self.title = title
        self.foregroundColor = foregroundColor
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImageName)
                    .foregroundStyle(imageForegroundColor)
                Text(title)
            }
            .fontSize(AppFontSize.caption, weight: .semibold)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule().fill(Color(AppColor.placeholder.opacity(0.1)))
            }
        }
        .buttonStyle(.plain)
    }
}
