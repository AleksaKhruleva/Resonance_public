import SwiftUI
import UIComponents
import Core

struct MiniPlayerView: View {

    @Environment(AudioPlayerStore.self) private var audioPlayerStore

    private let item: MiniPlayerItem
    private let onTap: () -> Void

    private static let buttonSize: CGFloat = 24

    init(
        item: MiniPlayerItem,
        onTap: @escaping () -> Void
    ) {
        self.item = item
        self.onTap = onTap
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onTap()
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .fontSize(AppFontSize.caption)
                            .foregroundStyle(AppColor.placeholder)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                audioPlayerStore.togglePlayPause()
            } label: {
                Image(systemName: audioPlayerStore.isPlaying ? "pause.fill" : "play.fill")
                    .fontSize(20, weight: .medium)
                    .frame(minWidth: Self.buttonSize, minHeight: Self.buttonSize)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            Button {
                audioPlayerStore.stop()
            } label: {
                Image(systemName: "xmark")
                    .fontSize(18, weight: .medium)
                    .frame(minWidth: Self.buttonSize, minHeight: Self.buttonSize)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
}
