import SwiftUI

public struct TrailingFadeHorizontalScrollView<Content: View>: View {

    private let hasItems: Bool
    private let availableScreenWidth: CGFloat
    private let spacing: CGFloat
    private let content: () -> Content

    private let trailingSpacerWidth: CGFloat
    private let gradientWidth: CGFloat

    public init(
        itemsCount: Int,
        itemWidth: CGFloat,
        availableScreenWidth: CGFloat,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.hasItems = itemsCount > 0
        self.availableScreenWidth = availableScreenWidth
        self.spacing = spacing
        self.content = content
        self.trailingSpacerWidth = max(availableScreenWidth - itemWidth - spacing - AppSize.horizontalPadding * 2, 0)
        self.gradientWidth = availableScreenWidth - itemWidth
    }

    public var body: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: spacing) {
                    content()

                    if hasItems {
                        Color.clear.frame(width: trailingSpacerWidth)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.never)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)

            if hasItems {
                LinearGradient(
                    colors: [
                        AppColor.background.opacity(0),
                        AppColor.background.opacity(0.7),
                        AppColor.background,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: gradientWidth)
                .allowsHitTesting(false)
            }
        }
    }
}
