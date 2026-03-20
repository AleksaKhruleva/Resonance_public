import SwiftUI

public struct SettingsNavigationRow: View {

    private let isDestructive: Bool
    private let iconName: String
    private let title: String
    private let action: () -> Void

    public init(
        isDestructive: Bool = false,
        iconName: String,
        title: String,
        action: @escaping () -> Void
    ) {
        self.isDestructive = isDestructive
        self.iconName = iconName
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconName)
                    .fontSize(18)
                    .frame(minWidth: AppSize.settingsIconMinWidht)
                    .foregroundColor(isDestructive ? AppColor.red : AppColor.blue)

                Text(title)
                    .foregroundColor(isDestructive ? AppColor.red : AppColor.text)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(isDestructive ? AppColor.red : AppColor.text)
                    .fontSize(AppFontSize.caption)
            }
            .fontWeight(.medium)
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(DarkeningButtonStyle())
    }
}
