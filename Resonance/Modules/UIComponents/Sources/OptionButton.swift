import SwiftUI

public struct OptionButton: View {

    private let iconName: String
    private let title: String
    private let isSelected: Bool
    private let action: () -> Void

    private var foregroundColor: Color {
        isSelected ? AppColor.lightText : AppColor.text
    }

    private var backgroundColor: Color {
        isSelected ? AppColor.blue : AppColor.placeholder.opacity(0.1)
    }

    public init(
        iconName: String,
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                Text(title)
            }
            .foregroundStyle(foregroundColor)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .frame(height: AppSize.compactControlHeight)
            .background(Capsule().fill(backgroundColor))
        }
    }
}
