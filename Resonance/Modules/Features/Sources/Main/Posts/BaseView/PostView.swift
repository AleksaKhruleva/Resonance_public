import SwiftUI
import UIComponents
import Core

struct PostView: View {

    private let post: Post
    private let shouldDisableLikeButton: Bool
    private let onAuthorTap: (() -> Void)?
    private let onLikeTap: (() -> Void)?
    private let onReportTap: (() -> Void)?
    private let onDeleteTap: (() -> Void)?

    private var formattedAudioDuration: String {
        guard let seconds = post.audio?.durationSeconds else {
            return AudioDurationFormatter.defaultString
        }
        return AudioDurationFormatter.string(from: seconds)
    }

    private var audioPlayerItem: MiniPlayerItem? {
        guard let audio = post.audio else { return nil }

        return MiniPlayerItem(
            id: "post-\(post.id)",
            title: post.authorNick,
            subtitle: "пост",
            audio: audio
        )
    }

    private var shouldShowActionButton: Bool {
        !post.isOwnedByCurrentUser || onDeleteTap != nil
    }

    init(
        post: Post,
        shouldDisableLikeButton: Bool,
        onAuthorTap: (() -> Void)?,
        onLikeTap: (() -> Void)?,
        onReportTap: (() -> Void)? = nil,
        onDeleteTap: (() -> Void)? = nil
    ) {
        self.post = post
        self.shouldDisableLikeButton = shouldDisableLikeButton
        self.onAuthorTap = onAuthorTap
        self.onLikeTap = onLikeTap
        self.onReportTap = onReportTap
        self.onDeleteTap = onDeleteTap
    }

    var body: some View {
        VStack {
            header
            content
            footer
        }
    }

    private var header: some View {
        HStack {
            HStack {
                AvatarView(imageData: post.authorAvatarData)
                Text(post.authorNick)
                    .fontWeight(.semibold)
            }
            .onTapGesture {
                onAuthorTap?()
            }
            PublicationDateView(date: PublicationDateFormatter.beautifulDate(from: post.publishDate))
            Spacer()
            if shouldShowActionButton {
                MediaActionButton(
                    shouldShowReportButton: !post.isOwnedByCurrentUser,
                    shouldShowDeleteButton: post.isOwnedByCurrentUser,
                    onReportTap: onReportTap,
                    onDeleteTap: onDeleteTap,
                    menuContent: {}
                )
            }
        }
        .padding(.horizontal, AppSize.horizontalPadding)
    }

    private var content: some View {
        PostImageView(imageData: post.imageData)
    }

    private var footer: some View {
        HStack {
            Text("Нравится: \(post.likesCount)")
                .fontWeight(.semibold)

            Spacer()

            if let audioPlayerItem {
                PostAudioButton(
                    item: audioPlayerItem,
                    title: formattedAudioDuration
                )
            }

            Button {
                onLikeTap?()
            } label: {
                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                    .fontSize(22, weight: .medium)
                    .foregroundStyle(post.isLiked ? AppColor.red : AppColor.text)
            }
            .buttonStyle(.plain)
            .disabled(shouldDisableLikeButton)
        }
        .padding(.horizontal, AppSize.horizontalPadding)
    }
}

private struct PostImageView: View {

    private let imageData: Data?

    @State private var image: Image

    init(imageData: Data?) {
        self.imageData = imageData
        _image = State(initialValue: Image(data: imageData))
    }

    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .onChange(of: imageData) { _, imageData in
                image = Image(data: imageData)
            }
    }
}

private struct PostAudioButton: View {

    @Environment(AudioPlayerStore.self) private var audioPlayerStore

    private let item: MiniPlayerItem
    private let title: String

    init(item: MiniPlayerItem, title: String) {
        self.item = item
        self.title = title
    }

    var body: some View {
        CapsuleButton(
            systemImageName: audioPlayerStore.isPlaying(item) ? "pause.fill" : "play.fill",
            title: title,
            foregroundColor: AppColor.blue
        ) {
            audioPlayerStore.handleTap(on: item)
        }
    }
}
