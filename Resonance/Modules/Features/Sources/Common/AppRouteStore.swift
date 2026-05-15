import Foundation

@MainActor
@Observable
public final class AppRouteStore {

    public enum Route: Equatable {
        case userProfile(userNick: String)
        case questionDetails(questionId: Int, answerId: Int?)
    }

    public var pendingRoute: Route?

    public init() {}

    public func open(_ route: Route) {
        pendingRoute = route
    }

    public func clear() {
        pendingRoute = nil
    }
}
