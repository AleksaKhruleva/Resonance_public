import SwiftUI
import Core

private struct ToastModifier: ViewModifier {

    let item: ToastItem?
    let onTap: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment) {
                if let item {
                    ToastView(
                        item: item,
                        onDismiss: onTap
                    )
                    .padding(edge(for: item.position), 12)
                    .transition(transition(for: item.position))
                }
            }
            .animation(
                .spring(response: 0.35, dampingFraction: 0.85),
                value: item
            )
    }

    private var alignment: Alignment {
        switch item?.position {
        case .top:
            return .top
        case .bottom, .none:
            return .bottom
        }
    }

    private func edge(for position: ToastPosition) -> Edge.Set {
        switch position {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }

    private func transition(for position: ToastPosition) -> AnyTransition {
        switch position {
        case .top:
            return .move(edge: .top).combined(with: .opacity)
        case .bottom:
            return .move(edge: .bottom).combined(with: .opacity)
        }
    }
}

public extension View {
    func toast(
        _ item: ToastItem?,
        onTap: @escaping () -> Void
    ) -> some View {
        modifier(
            ToastModifier(
                item: item,
                onTap: onTap
            )
        )
    }
}
