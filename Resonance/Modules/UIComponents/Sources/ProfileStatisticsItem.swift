import SwiftUI

public struct ProfileStatisticsItem: View {

    private let title: String
    private let value: Int
    private let onTap: (() -> Void)?

    public init(
        title: String,
        value: Int,
        onTap: (() -> Void)?
    ) {
        self.title = title
        self.value = value
        self.onTap = onTap
    }

    public var body: some View {
        VStack {
            Text("\(value)")
                .fontWeight(.semibold)
            Text(title)
                .fontSize(AppFontSize.caption, weight: .medium)
                .foregroundStyle(AppColor.placeholder)
        }
        .frame(maxWidth: .infinity)
        .onTapGesture {
            onTap?()
        }
    }
}
