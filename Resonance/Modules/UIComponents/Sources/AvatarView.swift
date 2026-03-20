import SwiftUI

public struct AvatarView: View {

    private let imageData: Data?
    private let frame: CGFloat

    public init(imageData: Data?, frame: CGFloat = 40) {
        self.imageData = imageData
        self.frame = frame
    }

    public var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
            } else {
                Circle().fill(Color(.systemGray5)).overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(AppColor.placeholder)
                        .fontSize(frame / 2)
                }
            }
        }
        .frame(width: frame, height: frame)
    }
}
