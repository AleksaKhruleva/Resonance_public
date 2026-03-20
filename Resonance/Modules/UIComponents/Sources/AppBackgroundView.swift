import SwiftUI

public struct AppBackgroundView: View {
    
    public init() {}
    
    public var body: some View {
        AppColor.background
            .ignoresSafeArea()
            .background {
                HostingControllerBackgroundView(
                    color: UIComponentsAsset.backgroundColor.color
                )
            }
    }
}

private struct HostingControllerBackgroundView: UIViewControllerRepresentable {

    let color: UIColor

    func makeUIViewController(context: Context) -> HostingBackgroundViewController {
        HostingBackgroundViewController(color: color)
    }

    func updateUIViewController(_ viewController: HostingBackgroundViewController, context: Context) {
        viewController.color = color
        viewController.applyBackgroundColor()
    }
}

private final class HostingBackgroundViewController: UIViewController {

    var color: UIColor {
        didSet {
            applyBackgroundColor()
        }
    }

    init(color: UIColor) {
        self.color = color
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        applyBackgroundColor()
    }

    func applyBackgroundColor() {
        parent?.view.backgroundColor = color
    }
}
