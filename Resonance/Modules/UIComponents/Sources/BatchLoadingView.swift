import SwiftUI

public struct BatchLoadingView: View {

    public init () {}

    public var body: some View {
        ProgressView()
            .tint(AppColor.text)
            .frame(height: 60)
            .frame(maxWidth: .infinity)
    }
}
