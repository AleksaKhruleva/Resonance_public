import SwiftUI

public enum WixFontWeight {
    
    case regular
    case medium
    case semibold
    case bold
    case extraBold
    
    var fontConvertible: UIComponentsFontConvertible {
        switch self {
            case .regular: return UIComponentsFontFamily.WixMadeforDisplay.regular
            case .medium: return UIComponentsFontFamily.WixMadeforDisplay.medium
            case .semibold: return UIComponentsFontFamily.WixMadeforDisplay.semiBold
            case .bold: return UIComponentsFontFamily.WixMadeforDisplay.bold
            case .extraBold: return UIComponentsFontFamily.WixMadeforDisplay.extraBold
        }
    }
}

struct WixFontModifier: ViewModifier {
    
    private let weight: WixFontWeight
    private let color: Color
    private let size: CGFloat

    init(weight: WixFontWeight, color: Color, size: CGFloat) {
        self.weight = weight
        self.color = color
        self.size = size
    }

    func body(content: Content) -> some View {
        content
            .font(weight.fontConvertible.swiftUIFont(size: size))
            .foregroundStyle(color)
    }
}

public extension View {
    func wixFont(_ weight: WixFontWeight = .medium, color: Color = AppColor.text, size: CGFloat = AppFontSize.body) -> some View {
        modifier(WixFontModifier(weight: weight, color: color, size: size))
    }
}
