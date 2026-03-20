import SwiftUI
import UIComponents
import Core

struct QuestionView: View {

    enum PresentationMode {
        case feed
        case details
    }

    private let question: Question
    private let presentationMode: PresentationMode
    private let onAuthorTap: (() -> Void)?
    private let onRecipientTap: ((String) -> Void)?
    private let onDetailsTap: (() -> Void)?
    private let onAnswerTap: (() -> Void)?
    private let onReportTap: (() -> Void)?
    private let onDeleteTap: (() -> Void)?
    private let animatesTextExpansion: Bool

    @Environment(UserStore.self) private var userStore
    @Environment(AudioPlayerStore.self) private var audioPlayerStore

    @State private var isExpanded = false

    private var shouldHideAuthorData: Bool {
        question.isAnonymous && !question.isOwnedByCurrentUser
    }

    private var shouldShowAnonymityInfo: Bool {
        question.isAnonymous && question.isOwnedByCurrentUser
    }

    private var shouldShowAnswerButton: Bool {
        guard onAnswerTap != nil else {
            return false
        }
        if question.isOwnedByCurrentUser {
            return false
        }

        if let recipient = question.recipient {
            guard recipient.id == userStore.currentUser.id else {
                return false
            }
            return question.answersCount == 0
        }

        return true
    }

    private var shouldShowActionButton: Bool {
        !question.isOwnedByCurrentUser || onDeleteTap != nil
    }

    private var formattedAudioDuration: String {
        guard let seconds = question.audio?.durationSeconds else {
            return AudioDurationFormatter.defaultString
        }
        return AudioDurationFormatter.string(from: seconds)
    }

    private var audioPlayerTitle: String {
        shouldHideAuthorData ? "Анонимный вопрос" : question.authorNick
    }

    private var audioPlayerItem: MiniPlayerItem? {
        guard let audio = question.audio, audio.durationSeconds > 0 else { return nil }

        return MiniPlayerItem(
            id: "question-\(question.id)",
            title: audioPlayerTitle,
            subtitle: "вопрос",
            audio: audio
        )
    }

    init(
        question: Question,
        presentationMode: PresentationMode,
        onAuthorTap: (() -> Void)?,
        onRecipientTap: ((String) -> Void)?,
        onDetailsTap: (() -> Void)? = nil,
        onAnswerTap: (() -> Void)? = nil,
        onReportTap: (() -> Void)? = nil,
        onDeleteTap: (() -> Void)? = nil,
        animatesTextExpansion: Bool = true
    ) {
        self.question = question
        self.presentationMode = presentationMode
        self.onAuthorTap = onAuthorTap
        self.onRecipientTap = onRecipientTap
        self.onDetailsTap = onDetailsTap
        self.onAnswerTap = onAnswerTap
        self.onReportTap = onReportTap
        self.onDeleteTap = onDeleteTap
        self.animatesTextExpansion = animatesTextExpansion
        _isExpanded = State(initialValue: presentationMode == .details)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
            footer
        }
    }

    @ViewBuilder
    private var header: some View {
        let nick = shouldHideAuthorData ? "Анонимный вопрос" : question.authorNick
        let avatarData = shouldHideAuthorData ? nil : question.authorAvatarData

        VStack(alignment: .leading) {
            HStack {
                HStack {
                    AvatarView(imageData: avatarData)
                    Text(nick).fontWeight(.semibold)
                }
                .onTapGesture {
                    guard !shouldHideAuthorData else { return }
                    onAuthorTap?()
                }
                PublicationDateView(date: PublicationDateFormatter.beautifulDate(from: question.publishDate))
                Spacer()
                if shouldShowActionButton {
                    MediaActionButton(
                        shouldShowReportButton: !question.isOwnedByCurrentUser,
                        shouldShowDeleteButton: question.isOwnedByCurrentUser && onDeleteTap != nil,
                        onReportTap: onReportTap,
                        onDeleteTap: onDeleteTap,
                        menuContent: {}
                    )
                }
            }

            if let recipient = question.recipient {
                HStack {
                    Text("Вопрос для")
                        .foregroundStyle(AppColor.placeholder)
                    HStack {
                        AvatarView(imageData: recipient.avatarData, frame: 32)
                        Text(recipient.nick).fontWeight(.semibold)
                    }
                    .onTapGesture {
                        onRecipientTap?(recipient.nick)
                    }
                }
                .fontSize(AppFontSize.caption)
            }

            if shouldShowAnonymityInfo {
                Text("Это анонимный вопрос - другие пользователи не видят ваш профиль")
                    .fontSize(AppFontSize.caption)
                    .foregroundStyle(AppColor.placeholder)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var content: some View {
        ExpandableTextView(
            text: question.text,
            isExpanded: $isExpanded,
            allowsCollapse: presentationMode == .feed,
            animatesExpansion: animatesTextExpansion
        )
        .padding(.top, 12)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            if let audioPlayerItem {
                CapsuleButton(
                    systemImageName: audioPlayerStore.isPlaying(audioPlayerItem) ? "pause.fill" : "play.fill",
                    title: formattedAudioDuration,
                    foregroundColor: AppColor.blue
                ) {
                    audioPlayerStore.handleTap(on: audioPlayerItem)
                }
            }

            CapsuleButton(
                systemImageName: "ellipsis.message",
                title: "\(question.answersCount)"
            ) {
                onDetailsTap?()
            }

            if shouldShowAnswerButton {
                CapsuleButton(
                    systemImageName: "plus.message",
                title: "Ответить"
            ) {
                onAnswerTap?()
            }
        }
        }
        .padding(.top, 12)
    }
}
