import SwiftUI

public extension View {

    func fontSize(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: size, weight: weight))
    }

    func readSize(_ size: Binding<CGSize>) -> some View {
        modifier(SizeReaderModifier(size: size))
    }
}
