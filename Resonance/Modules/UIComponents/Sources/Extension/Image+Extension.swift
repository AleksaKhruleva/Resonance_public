import SwiftUI

public extension Image {
    init(data: Data?, size: CGSize = CGSize(width: 100, height: 100)) {
        let uiImage: UIImage

        if let data, let image = UIImage(data: data) {
            uiImage = image
        } else {
            let renderer = UIGraphicsImageRenderer(size: size)
            uiImage = renderer.image { context in
                UIComponentsAsset.placeholderTextColor.color.withAlphaComponent(0.5).setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
        }

        self.init(uiImage: uiImage)
    }
}
