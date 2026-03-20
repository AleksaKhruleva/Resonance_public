import SwiftUI
import Core
import UIComponents

struct AnswerView: View {

    @Environment(AudioPlayerStore.self) private var audioPlayerStore

    private let answer: Answer
    private let presentationMode: QuestionView.PresentationMode
    private let shouldDisableLikeButton: Bool
    private let onAuthorTap: (() -> Void)?
    private let onLikeTap: (() -> Void)?
    private let onReportTap: (() -> Void)?
    private let onDeleteTap: (() -> Void)?
    private let onBestTap: (() -> Void)?

    private var shouldShowActionButton: Bool {
        !answer.isOwnedByCurrentUser || onDeleteTap != nil || onBestTap != nil
    }

    private var fontSize: CGFloat {
        switch presentationMode {
        case .feed:
            AppFontSize.caption
        case .details:
            AppFontSize.body
        }
    }

    private var formattedAudioDuration: String {
        guard let seconds = answer.audio?.durationSeconds else {
            return AudioDurationFormatter.defaultString
        }
        return AudioDurationFormatter.string(from: seconds)
    }

    private var audioPlayerItem: MiniPlayerItem? {
        guard let audio = answer.audio else { return nil }

        return MiniPlayerItem(
            id: "answer-\(answer.id)",
            title: answer.authorNick,
            subtitle: "ответ",
            audio: audio
        )
    }

    init(
        answer: Answer,
        presentationMode: QuestionView.PresentationMode,
        shouldDisableLikeButton: Bool = false,
        onAuthorTap: (() -> Void)?,
        onLikeTap: (() -> Void)? = nil,
        onReportTap: (() -> Void)? = nil,
        onDeleteTap: (() -> Void)? = nil,
        onBestTap: (() -> Void)? = nil
    ) {
        self.answer = answer
        self.presentationMode = presentationMode
        self.shouldDisableLikeButton = shouldDisableLikeButton
        self.onAuthorTap = onAuthorTap
        self.onLikeTap = onLikeTap
        self.onReportTap = onReportTap
        self.onDeleteTap = onDeleteTap
        self.onBestTap = onBestTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
            footer
        }
        .fontSize(fontSize)
    }

    private var header: some View {
        HStack {
            HStack {
                AvatarView(imageData: answer.authorAvatarData)
                Text(answer.authorNick).fontWeight(.semibold)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onAuthorTap?()
            }
            PublicationDateView(date: PublicationDateFormatter.beautifulDate(from: answer.publishDate))
            Spacer()
            if shouldShowActionButton {
                MediaActionButton(
                    shouldShowReportButton: !answer.isOwnedByCurrentUser,
                    shouldShowDeleteButton: answer.isOwnedByCurrentUser && onDeleteTap != nil,
                    onReportTap: onReportTap,
                    onDeleteTap: onDeleteTap,
                    menuContent: {
                        if let onBestTap {
                            Button {
                                onBestTap()
                            } label: {
                                Label(
                                    answer.isBest ? "Снять пометку \"Лучший\"" : "Лучший ответ",
                                    systemImage: answer.isBest ? "star.slash" : "star"
                                )
                            }
                        }
                    }
                )
            }
        }
    }

    private var content: some View {
        VStack {
            Spacer(minLength: 0)
            Text(answer.text)
                .lineLimit(presentationMode == .feed ? 3 : nil)
            Spacer(minLength: 0)
        }
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
                systemImageName: answer.isLiked ? "heart.fill" : "heart",
                title: "\(answer.likesCount)",
                imageForegroundColor: answer.isLiked ? AppColor.red : AppColor.text
            ) {
                onLikeTap?()
            }
            .disabled(shouldDisableLikeButton)

            CapsuleButton(
                systemImageName: "star.fill",
                title: "Лучший",
                foregroundColor: AppColor.greenText
            ) {
                // nothing to do
            }
            .opacity(answer.isBest ? 1 : 0)
            .allowsHitTesting(false)
        }
    }
}
