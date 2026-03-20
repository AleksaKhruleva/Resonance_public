import SwiftUI
import Core
import UIComponents

struct NotificationRow: View {

    private struct Constants {
        static let leadingImageframe: CGFloat = 44
    }

    private let item: NotificationItem
    private let onRowTap: (() -> Void)?
    private let onAvatarTap: (() -> Void)?

    init(
        item: NotificationItem,
        onRowTap: (() -> Void)? = nil,
        onAvatarTap: (() -> Void)? = nil
    ) {
        self.item = item
        self.onRowTap = onRowTap
        self.onAvatarTap = onAvatarTap
    }

    var body: some View {
        HStack(spacing: 12) {
            avatarView
            rowContent
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var avatarView: some View {
        if let actor = item.actor, actor.id != 0 {
            Button {
                onAvatarTap?()
            } label: {
                AvatarView(imageData: actor.avatarData, frame: Constants.leadingImageframe)
            }
            .buttonStyle(.plain)
        } else {
            Circle()
                .fill(AppColor.placeholder.opacity(0.15))
                .frame(width: Constants.leadingImageframe, height: Constants.leadingImageframe)
                .overlay {
                    Image(systemName: item.type.iconName)
                        .foregroundStyle(AppColor.placeholder)
                        .fontSize(20)
                }
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        if let onRowTap {
            content
                .onTapGesture {
                onRowTap()
            }
        } else {
            content
        }
    }

    private var content: some View {
        HStack {
            VStack(alignment: .leading) {
                item.title
                    .multilineTextAlignment(.leading)

                Text(item.createdAtText)
                    .fontSize(AppFontSize.date)
                    .foregroundColor(AppColor.placeholder)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
