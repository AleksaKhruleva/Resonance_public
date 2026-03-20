import SwiftUI

public struct DarkeningButtonStyle: ButtonStyle {

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                AppColor.text.opacity(configuration.isPressed ? 0.06 : 0)
            )
    }
}
