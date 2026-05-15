import SwiftUI
import UIKit

public enum ImageCropShape: Sendable {
    case circle
    case square
}

public struct ImageCropperView: View {

    private let image: UIImage
    private let cropShape: ImageCropShape
    private let onCancel: () -> Void
    private let onComplete: (UIImage) -> Void

    private let horizontalPadding: CGFloat = AppSize.horizontalPadding 
    private let cropVerticalPadding: CGFloat = 18
    private let maxScaleMultiplier: CGFloat = 8

    @State private var committedScale: CGFloat?
    @State private var gestureScale: CGFloat = 1

    @State private var committedOffset: CGSize = .zero
    @State private var gestureOffset: CGSize = .zero

    public init(
        image: UIImage,
        cropShape: ImageCropShape,
        onCancel: @escaping () -> Void,
        onComplete: @escaping (UIImage) -> Void
    ) {
        self.image = image.normalized()
        self.cropShape = cropShape
        self.onCancel = onCancel
        self.onComplete = onComplete
    }

    public var body: some View {
        GeometryReader { proxy in
            let topInset = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
                .max() ?? 52
            let cropSize = max(
                1,
                min(
                    proxy.size.width - horizontalPadding * 2,
                    proxy.size.height - cropVerticalPadding * 2
                )
            )
            let minimumScale = minimumScale(for: cropSize)
            let baseScale = max(committedScale ?? minimumScale, minimumScale)
            let currentScale = clampedScale(baseScale * gestureScale, minimumScale: minimumScale)
            let currentOffset = clampedOffset(
                committedOffset + gestureOffset,
                cropSize: cropSize,
                scale: currentScale
            )

            ZStack {
                AppBackgroundView()

                cropViewport(
                    viewportSize: proxy.size,
                    cropSize: cropSize,
                    scale: currentScale,
                    offset: currentOffset,
                    minimumScale: minimumScale
                )
                .onAppear {
                    if committedScale == nil {
                        committedScale = minimumScale
                    }
                }

                VStack {
                    HStack {
                        Button(action: onCancel) {
                            Image(systemName: "xmark")
                                .padding(4)
                        }

                        Spacer()

                        Button {
                            onComplete(
                                croppedImage(
                                    cropSize: cropSize,
                                    scale: currentScale,
                                    offset: currentOffset
                                )
                            )
                        } label: {
                            Image(systemName: "checkmark")
                                .padding(4)
                        }
                    }
                    .wixFont(.semibold, color: AppColor.blue, size: 20)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)

                    Spacer()
                }
                .padding(.top, topInset + 8)
                .padding(.horizontal, 12)
            }
        }
    }

    private func cropViewport(
        viewportSize: CGSize,
        cropSize: CGFloat,
        scale: CGFloat,
        offset: CGSize,
        minimumScale: CGFloat
    ) -> some View {
        let cropRect = CGRect(
            x: (viewportSize.width - cropSize) / 2,
            y: (viewportSize.height - cropSize) / 2,
            width: cropSize,
            height: cropSize
        )
        let displayedImageSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        return ZStack {
            Image(uiImage: image)
                .resizable()
                .frame(
                    width: displayedImageSize.width,
                    height: displayedImageSize.height
                )
                .position(
                    x: cropRect.midX + offset.width,
                    y: cropRect.midY + offset.height
                )

            CutoutOverlayShape(
                cropRect: cropRect,
                cropShape: cropShape
            )
            .fill(AppColor.background.opacity(0.8), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            cropBorder(size: cropSize)
                .position(x: cropRect.midX, y: cropRect.midY)
                .allowsHitTesting(false)
        }
        .frame(width: viewportSize.width, height: viewportSize.height)
        .contentShape(Rectangle())
        .clipped()
        .gesture(
            dragGesture(cropSize: cropSize, scale: scale)
        )
        .simultaneousGesture(
            magnifyGesture(cropSize: cropSize, minimumScale: minimumScale)
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                toggleZoom(cropSize: cropSize, minimumScale: minimumScale)
            }
        }
    }

    private func cropBorder(size: CGFloat) -> some View {
        let shape: AnyShape = cropShape == .circle ? AnyShape(Circle()) : AnyShape(Rectangle())

        return shape
            .stroke(AppColor.text, lineWidth: 1)
            .frame(width: size, height: size)
    }

    private func dragGesture(cropSize: CGFloat, scale: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let candidateOffset = committedOffset + value.translation
                let clamped = clampedOffset(
                    candidateOffset,
                    cropSize: cropSize,
                    scale: scale
                )
                gestureOffset = clamped - committedOffset
            }
            .onEnded { value in
                committedOffset = clampedOffset(
                    committedOffset + value.translation,
                    cropSize: cropSize,
                    scale: scale
                )
                gestureOffset = .zero
            }
    }

    private func magnifyGesture(cropSize: CGFloat, minimumScale: CGFloat) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                gestureScale = value.magnification
                let resolvedScale = clampedScale(
                    (committedScale ?? minimumScale) * value.magnification,
                    minimumScale: minimumScale
                )
                let currentOffset = committedOffset + gestureOffset
                let clamped = clampedOffset(
                    currentOffset,
                    cropSize: cropSize,
                    scale: resolvedScale
                )
                gestureOffset = clamped - committedOffset
            }
            .onEnded { value in
                let resolvedScale = clampedScale(
                    (committedScale ?? minimumScale) * value.magnification,
                    minimumScale: minimumScale
                )
                committedScale = resolvedScale
                committedOffset = clampedOffset(
                    committedOffset + gestureOffset,
                    cropSize: cropSize,
                    scale: resolvedScale
                )
                gestureScale = 1
                gestureOffset = .zero
            }
    }

    private func toggleZoom(cropSize: CGFloat, minimumScale: CGFloat) {
        let currentCommittedScale = committedScale ?? minimumScale
        let targetScale: CGFloat

        if currentCommittedScale > minimumScale * 1.5 {
            targetScale = minimumScale
        } else {
            targetScale = clampedScale(
                minimumScale * 2,
                minimumScale: minimumScale
            )
        }

        committedScale = targetScale
        committedOffset = clampedOffset(
            committedOffset,
            cropSize: cropSize,
            scale: targetScale
        )
        gestureScale = 1
        gestureOffset = .zero
    }

    private func minimumScale(for cropSize: CGFloat) -> CGFloat {
        max(
            cropSize / image.size.width,
            cropSize / image.size.height
        )
    }

    private func clampedScale(_ scale: CGFloat, minimumScale: CGFloat) -> CGFloat {
        min(
            max(scale, minimumScale),
            minimumScale * maxScaleMultiplier
        )
    }

    private func clampedOffset(_ offset: CGSize, cropSize: CGFloat, scale: CGFloat) -> CGSize {
        let displayedWidth = image.size.width * scale
        let displayedHeight = image.size.height * scale
        let horizontalLimit = max(0, (displayedWidth - cropSize) / 2)
        let verticalLimit = max(0, (displayedHeight - cropSize) / 2)

        return CGSize(
            width: min(max(offset.width, -horizontalLimit), horizontalLimit),
            height: min(max(offset.height, -verticalLimit), verticalLimit)
        )
    }

    private func croppedImage(cropSize: CGFloat, scale: CGFloat, offset: CGSize) -> UIImage {
        let cropLengthInImage = cropSize / scale
        let cropOrigin = CGPoint(
            x: (image.size.width - cropLengthInImage) / 2 - offset.width / scale,
            y: (image.size.height - cropLengthInImage) / 2 - offset.height / scale
        )
        let cropRectInPoints = CGRect(
            origin: cropOrigin,
            size: CGSize(width: cropLengthInImage, height: cropLengthInImage)
        ).intersection(
            CGRect(origin: .zero, size: image.size)
        )

        let pixelScale = image.scale
        let cropRectInPixels = CGRect(
            x: cropRectInPoints.origin.x * pixelScale,
            y: cropRectInPoints.origin.y * pixelScale,
            width: cropRectInPoints.size.width * pixelScale,
            height: cropRectInPoints.size.height * pixelScale
        ).integral

        if let cgImage = image.cgImage?.cropping(to: cropRectInPixels) {
            return UIImage(
                cgImage: cgImage,
                scale: image.scale,
                orientation: .up
            )
        }

        let renderer = UIGraphicsImageRenderer(size: cropRectInPoints.size)
        return renderer.image { _ in
            image.draw(
                at: CGPoint(
                    x: -cropRectInPoints.origin.x,
                    y: -cropRectInPoints.origin.y
                )
            )
        }
    }
}

private struct CutoutOverlayShape: Shape {

    private let cropRect: CGRect
    private let cropShape: ImageCropShape

    init(cropRect: CGRect, cropShape: ImageCropShape) {
        self.cropRect = cropRect
        self.cropShape = cropShape
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)

        switch cropShape {
            case .circle:
                path.addEllipse(in: cropRect)
            case .square:
                path.addRect(cropRect)
        }

        return path
    }
}

private extension UIImage {
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(
            width: lhs.width + rhs.width,
            height: lhs.height + rhs.height
        )
    }

    static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(
            width: lhs.width - rhs.width,
            height: lhs.height - rhs.height
        )
    }
}
