import SwiftUI

public struct PublicationDateView: View {

    private let date: String
    private let fontSize: CGFloat

    public init(date: String, fontSize: CGFloat = AppFontSize.date) {
        self.date = date
        self.fontSize = fontSize
    }

    public var body: some View {
        HStack {
            Image(systemName: "circle.fill")
                .fontSize(AppFontSize.circleSeparator)
            Text(date)
                .fontSize(fontSize)
        }
        .foregroundColor(AppColor.placeholder)
    }
}
