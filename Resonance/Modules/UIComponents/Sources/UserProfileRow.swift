import SwiftUI

public struct UserProfileRow: View {

    private let avatarData: Data?
    private let nick: String
    private let onTap: (() -> Void)?

    public init(
        avatarData: Data?,
        nick: String,
        onTap: (() -> Void)?
    ) {
        self.avatarData = avatarData
        self.nick = nick
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            onTap?()
        } label: {
            HStack {
                AvatarView(imageData: avatarData)

                Text(nick).fontWeight(.semibold)

                Spacer()

                Image(systemName: "chevron.right")
                    .fontSize(AppFontSize.caption, weight: .medium)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, AppSize.horizontalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(DarkeningButtonStyle())
    }
}
