import SwiftUI
import UIComponents
import Core

public struct TabsCoordinator: View {

    private enum Tab: Int {
        case questions
        case posts
        case create
        case search
        case profile
    }

    private let onLogout: () -> Void

    @State private var selectedTab: Tab = .questions
    @State private var questionsRefreshTrigger = 0
    @State private var questionsRefreshFilter: QuestionsFeedViewModel.FeedFilter?
    @State private var postsRefreshTrigger = 0
    @State private var audioPlayerStore = AudioPlayerStore()

    public init(
        onLogout: @escaping () -> Void = {}
    ) {
        self.onLogout = onLogout
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            QuestionsCoordinator(
                refreshTrigger: $questionsRefreshTrigger,
                refreshFilter: $questionsRefreshFilter,
                onLogout: onLogout
            )
                .tabItem { Image(systemName: "questionmark.message") }
                .tag(Tab.questions)

            PostsCoordinator(
                refreshTrigger: $postsRefreshTrigger,
                onLogout: onLogout
            )
                .tabItem { Image(systemName: "house") }
                .tag(Tab.posts)

            CreateCoordinator(
                onPostPublished: {
                    postsRefreshTrigger += 1
                    selectedTab = .posts
                },
                onQuestionPublished: {
                    questionsRefreshFilter = .outgoing
                    questionsRefreshTrigger += 1
                    selectedTab = .questions
                }
            )
            .tabItem { Image(systemName: "plus") }
            .tag(Tab.create)

            SearchCoordinator(onLogout: onLogout)
                .tabItem { Image(systemName: "magnifyingglass") }
                .tag(Tab.search)

            RootProfileCoordinator(onLogout: onLogout)
                .tabItem { Image(systemName: "person") }
                .tag(Tab.profile)
        }
        .tabViewBottomAccessory(isEnabled: audioPlayerStore.currentItem != nil) {
            if let item = audioPlayerStore.currentItem {
                AudioPlayerBottomAccessoryView(item: item)
            }
        }
        .environment(audioPlayerStore)
        .font(.system(size: AppFontSize.body, weight: .regular))
        .foregroundStyle(AppColor.text)
    }
}

private struct AudioPlayerBottomAccessoryView: View {

    @Environment(AudioPlayerStore.self) private var audioPlayerStore
    @State private var isAudioPlayerPresented = false

    private let item: MiniPlayerItem

    init(item: MiniPlayerItem) {
        self.item = item
    }

    var body: some View {
        MiniPlayerView(
            item: item,
            onTap: {
                isAudioPlayerPresented = true
            }
        )
        .sheet(isPresented: $isAudioPlayerPresented) {
            if let item = audioPlayerStore.currentItem {
                AudioPlayerSheetView(item: item)
                    .environment(audioPlayerStore)
            }
        }
        .onChange(of: audioPlayerStore.currentItem) { _, item in
            guard item == nil else { return }
            isAudioPlayerPresented = false
        }
    }
}
