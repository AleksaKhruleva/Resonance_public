import SwiftUI

struct PlayfairFontModifier: ViewModifier {
    
    private let color: Color
    private let size: CGFloat

    init(color: Color, size: CGFloat) {
        self.color = color
        self.size = size
    }
    
    func body(content: Content) -> some View {
        content
            .font(UIComponentsFontFamily.PlayfairDisplay.blackItalic.swiftUIFont(size: size))
            .foregroundStyle(color)
    }
}

public extension View {
    func playfairFont(color: Color = AppColor.blue, size: CGFloat = 20) -> some View {
        modifier(PlayfairFontModifier(color: color, size: size))
    }
}
