import SwiftUI
import Core
import UIComponents

struct NotificationRow: View {

    private let notification: ResonanceNotification
    private let onAvatarTap: () -> Void
    private let onRowBodyTap: () -> Void

    private var isAnonymous: Bool {
        notification.initiatorNick?.nilIfEmpty == nil
    }

    init(
        notification: ResonanceNotification,
        onAvatarTap: @escaping () -> Void,
        onRowBodyTap: @escaping () -> Void
    ) {
        self.notification = notification
        self.onAvatarTap = onAvatarTap
        self.onRowBodyTap = onRowBodyTap
    }

    var body: some View {
        HStack(spacing: 12) {
            avatarView
            VStack(alignment: .leading, spacing: 4) {
                rowBodyContent
                publishDate
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onRowBodyTap()
            }
        }
        .padding(.vertical, 12)
    }

    private var avatarView: some View {
        AvatarView(
            imageData: notification.initiatorAvatarData,
            frame: 44
        )
        .onTapGesture {
            if !isAnonymous {
                onAvatarTap()
            }
        }
    }

    @ViewBuilder
    private var rowBodyContent: some View {
        switch notification.type {
        case .newFollower:
            newFollowerContent
        case .newQuestion:
            newQuestionContent
        case .newAnswer:
            newAnswerContent
        }
    }

    private var publishDate: some View {
        Text(PublicationDateFormatter.beautifulDate(from: notification.publishDate))
            .fontSize(AppFontSize.caption)
            .foregroundStyle(AppColor.placeholder)
    }

    @ViewBuilder
    private var newFollowerContent: some View {
        if let initiatorNick = notification.initiatorNick?.nilIfEmpty {
            Text("\(Text(initiatorNick).fontWeight(.semibold)) теперь ваш подписчик")
        }
    }

    @ViewBuilder
    private var newAnswerContent: some View {
        if let initiatorNick = notification.initiatorNick?.nilIfEmpty {
            Text("\(Text(initiatorNick).fontWeight(.semibold)) ответил(-а) на ваш вопрос")
        }
    }

    @ViewBuilder
    private var newQuestionContent: some View {
        if !isAnonymous, let initiatorNick = notification.initiatorNick?.nilIfEmpty {
            Text("\(Text(initiatorNick).fontWeight(.semibold)) задал(-а) вам новый вопрос")
        } else {
            Text("Вам задали новый вопрос")
        }
    }
}
