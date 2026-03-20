import Foundation

public enum ToastKind: Equatable {
    case success
    case error
}

public enum ToastPosition: Equatable {
    case top
    case bottom
}

public struct ToastItem: Identifiable, Equatable {

    public let id = UUID()
    public let message: String
    public let kind: ToastKind
    public let position: ToastPosition

    public init(
        message: String,
        kind: ToastKind,
        position: ToastPosition = .bottom
    ) {
        self.message = message
        self.kind = kind
        self.position = position
    }

    public static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}
