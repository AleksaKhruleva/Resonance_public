import SwiftUI

struct ToolbarTitleView: ViewModifier {

    private let title: String

    init(title: String) {
        self.title = title
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .wixFont(.bold, size: AppFontSize.toolbarTitle)
                }
            }
    }
}

public extension View {
    func toolbarTitle(_ title: String) -> some View {
        self.modifier(ToolbarTitleView(title: title))
    }
}
