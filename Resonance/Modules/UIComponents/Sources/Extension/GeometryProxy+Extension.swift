import SwiftUI

public extension GeometryProxy {
    var safeHeight: CGFloat {
        size.height - safeAreaInsets.top - safeAreaInsets.bottom
    }
}

