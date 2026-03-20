import SwiftUI
import Core

struct CreateCoordinator: View {

    @State private var path = NavigationPath()

    private let onPostPublished: (() -> Void)?
    private let onQuestionPublished: (() -> Void)?

    init(
        onPostPublished: (() -> Void)? = nil,
        onQuestionPublished: (() -> Void)? = nil
    ) {
        self.onPostPublished = onPostPublished
        self.onQuestionPublished = onQuestionPublished
    }

    var body: some View {
        NavigationStack(path: $path) {
            CreateView(
                onPostPublished: onPostPublished,
                onQuestionPublished: onQuestionPublished
            )
        }
    }
}
