import SwiftUI
import Networking
import Core

@MainActor
@Observable
final class SearchViewModel {

    // MARK: - Internal Types

    enum Intent {
        case updateQuery(String)
        case selectScope(SearchScope)
        case submitSearch
        case loadNextUsersBatchIfNeeded(userId: Int)
        case openUserProfile(userNick: String)
        case dismissToast
    }

    enum State: Equatable {
        case idle
        case loading
        case loadingNextBatch
        case content
        case empty
        case error(String?)
    }

    enum SearchScope: String, CaseIterable, Identifiable {
        case questions = "Вопросы"
        case users = "Люди"

        var id: Self { self }

        var textFieldPlaceholder: String {
            switch self {
            case .questions:
                return "Поиск вопросов"
            case .users:
                return "Поиск пользователей по нику"
            }
        }
    }

    // MARK: - Properties

    var query = ""
    var selectedScope: SearchScope = .users

    private(set) var toast: ToastItem?
    private(set) var state: State = .idle
    private(set) var foundUsers: [UserProfile] = []
    private(set) var foundQuestions: [Question] = []

    @ObservationIgnored
    private var searchTask: Task<Void, Never>?

    private let searchService: SearchService
    private let onUserTap: ((String) -> Void)?

    private var hasMoreUsers = true
    private var usersOffset = 0

    private static let searchDelayNanoseconds: UInt64 = 350_000_000
    private static let usersBatchSize = 15

    private var isLoading: Bool {
        state == .loading || state == .loadingNextBatch
    }

    // MARK: - Internal Init

    init(
        searchService: SearchService = SearchService(),
        onUserTap: ((String) -> Void)?
    ) {
        self.searchService = searchService
        self.onUserTap = onUserTap
    }

    deinit {
        searchTask?.cancel()
    }

    // MARK: - Internal Methods

    func handle(_ intent: Intent) {
        switch intent {
        case .updateQuery(let newValue):
            updateQuery(newValue)
        case .selectScope(let scope):
            selectScope(scope)
        case .submitSearch:
            searchTask?.cancel()
            Task { await search(query: query, scope: selectedScope) }
        case .loadNextUsersBatchIfNeeded(let userId):
            guard selectedScope == .users, userId == foundUsers.last?.id else { return }
            Task { await loadNextUsersBatch() }
        case .openUserProfile(let userNick):
            onUserTap?(userNick)
        case .dismissToast:
            toast = nil
        }
    }

    // MARK: - Private Methods

    private func updateQuery(_ newValue: String) {
        query = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        scheduleSearch()
    }

    private func selectScope(_ scope: SearchScope) {
        guard selectedScope != scope else { return }
        selectedScope = scope
        scheduleSearch()
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        guard !query.isEmpty else {
            clearResults()
            return
        }

        searchTask = Task { [query, selectedScope] in
            try? await Task.sleep(nanoseconds: Self.searchDelayNanoseconds)
            guard !Task.isCancelled else { return }
            await search(query: query, scope: selectedScope)
        }
    }

    private func search(query: String, scope: SearchScope) async {
        guard !query.isEmpty else {
            clearResults()
            return
        }

        state = .loading

        switch scope {
        case .questions:
            foundQuestions = []
            foundUsers = []
            state = .empty
        case .users:
            foundQuestions = []
            await searchUsers(by: query)
        }
    }

    private func searchUsers(by nick: String) async {
        usersOffset = 0
        hasMoreUsers = true

        let result = await searchService.findUsers(
            by: nick,
            offset: usersOffset,
            batchSize: Self.usersBatchSize
        )
        guard query == nick, selectedScope == .users, !Task.isCancelled else { return }

        switch result {
        case .success(let users):
            foundUsers = users
            usersOffset = users.count
            hasMoreUsers = users.count == Self.usersBatchSize
            state = users.isEmpty ? .empty : .content
        case .failure(let error):
            foundUsers = []
            usersOffset = 0
            hasMoreUsers = false
            state = .error(error.localizedDescription)
        }
    }

    private func loadNextUsersBatch() async {
        guard state == .content, hasMoreUsers, !isLoading else { return }

        let nick = query
        let offset = usersOffset
        state = .loadingNextBatch

        let result = await searchService.findUsers(
            by: nick,
            offset: offset,
            batchSize: Self.usersBatchSize
        )
        guard query == nick, selectedScope == .users, !Task.isCancelled else { return }

        switch result {
        case .success(let users):
            foundUsers.append(contentsOf: users)
            usersOffset += users.count
            hasMoreUsers = users.count == Self.usersBatchSize
            state = .content
        case .failure:
            state = .content
            showToast(.nextBatchLoadFailed)
        }
    }

    private func clearResults() {
        foundUsers = []
        foundQuestions = []
        usersOffset = 0
        hasMoreUsers = true
        state = .idle
    }

    private func showToast(_ message: ToastMessage) {
        toast = message.item
    }
}
