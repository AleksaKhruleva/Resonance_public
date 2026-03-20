import SwiftUI
import Core

struct NotificationItem: Identifiable, Hashable {

    enum Kind: Hashable {
        case newFollower
        case newDirectQuestion
        case newAnswer

        var iconName: String {
            switch self {
            case .newFollower:
                return "person.badge.plus"
            case .newDirectQuestion:
                return "questionmark.message"
            case .newAnswer:
                return "ellipsis.message"
            }
        }
    }

    enum Target: Hashable {
        case profile(userNick: String)
        case question(questionId: Int)
        case answer(questionId: Int, answerId: Int)
    }

    private let itemId: String
    private let itemType: Kind
    private let actorProfile: UserProfile?
    private let notificationCreatedAt: Date
    private let notificationCreatedAtText: String
    private let sourceNoticeId: Int
    private let notificationTarget: Target?

    var id: String { itemId }
    var type: Kind { itemType }
    var actor: UserProfile? { actorProfile }
    var createdAt: Date { notificationCreatedAt }
    var createdAtText: String { notificationCreatedAtText }
    var noticeId: Int { sourceNoticeId }
    var target: Target? { notificationTarget }

    var title: Text {
        switch type {
        case .newFollower:
            return Text("\(actorNick) теперь Ваш подписчик")
        case .newDirectQuestion:
            if isSystemActor {
                return Text("Вам задали анонимный адресный вопрос")
            }
            return Text("\(actorNick) задал(а) вам адресный вопрос")
        case .newAnswer:
            return Text("\(actorNick) ответил(а) на Ваш вопрос")
        }
    }

    init(
        id: String,
        type: Kind,
        actor: UserProfile?,
        createdAt: Date,
        createdAtText: String,
        noticeId: Int,
        target: Target?
    ) {
        self.itemId = id
        self.itemType = type
        self.actorProfile = actor
        self.notificationCreatedAt = createdAt
        self.notificationCreatedAtText = createdAtText
        self.sourceNoticeId = noticeId
        self.notificationTarget = target
    }

    init?(notice: Notice) {
        guard let payload = notice.payload else { return nil }

        let kind: Kind
        let actorUserId: Int
        let target: Target

        switch payload {
        case .newFollower(let userId, _):
            kind = .newFollower
            actorUserId = userId
            target = .profile(userNick: notice.initiatorNick)
        case .newDirectQuestion(let userId, _, let questionId):
            kind = .newDirectQuestion
            actorUserId = userId
            target = .question(questionId: questionId)
        case .newAnswer(let userId, _, let questionId, let answerId):
            kind = .newAnswer
            actorUserId = userId
            target = .answer(questionId: questionId, answerId: answerId)
        case .unsupported:
            return nil
        }

        self.init(
            id: String(notice.id),
            type: kind,
            actor: UserProfile.notificationActor(
                id: actorUserId,
                nick: notice.initiatorNick,
                avatarData: notice.initiatorAvatarData
            ),
            createdAt: PublicationDateFormatter.date(from: notice.publishDate) ?? .distantPast,
            createdAtText: PublicationDateFormatter.beautifulDate(from: notice.publishDate),
            noticeId: notice.id,
            target: target
        )
    }

    private var actorNick: Text {
        if let actor {
            return Text(actor.nick).bold()
        }
        return Text("Кто-то").bold()
    }

    private var isSystemActor: Bool {
        actor?.id == 0
    }
}

private extension UserProfile {

    static func notificationActor(
        id: Int,
        nick: String,
        avatarData: Data?
    ) -> UserProfile {
        UserProfile(
            id: id,
            email: "",
            nick: nick,
            avatarData: avatarData,
            isSubscribedByCurrentUser: false,
            postsCount: 0,
            subscribersCount: 0,
            subscriptionsCount: 0
        )
    }
}
