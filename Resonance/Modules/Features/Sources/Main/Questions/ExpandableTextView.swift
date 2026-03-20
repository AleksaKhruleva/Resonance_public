import SwiftUI
import UIComponents

struct ExpandableTextView: View {

    private enum Constants {
        static let collapsedLineLimit = 7
        static let expandThresholdLineCount = 8
    }

    private let text: String
    private let allowsCollapse: Bool
    private let animatesExpansion: Bool

    @Binding private var isExpanded: Bool
    @State private var availableWidth: CGFloat = 0
    @State private var measuredLineCount = 0

    private var shouldCollapse: Bool {
        measuredLineCount > Constants.expandThresholdLineCount
    }

    init(
        text: String,
        isExpanded: Binding<Bool>,
        allowsCollapse: Bool = true,
        animatesExpansion: Bool = true
    ) {
        self.text = text
        self.allowsCollapse = allowsCollapse
        self.animatesExpansion = animatesExpansion
        _isExpanded = isExpanded
    }

    var body: some View {
        Text(text)
            .fontWeight(.medium)
            .lineLimit(shouldCollapse && !isExpanded ? Constants.collapsedLineLimit : nil)
            .fixedSize(horizontal: false, vertical: true)
            .background(textWidthReader)
            .overlay(alignment: .bottomTrailing) {
                if shouldCollapse && !isExpanded {
                    moreButton
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard allowsCollapse, shouldCollapse, isExpanded else { return }
                setExpanded(false)
            }
            .onChange(of: text) {
                recalculateLineCount()
            }
    }

    private var textWidthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    updateAvailableWidth(proxy.size.width)
                }
                .onChange(of: proxy.size.width) { _, newWidth in
                    updateAvailableWidth(newWidth)
                }
        }
    }

    private var moreButton: some View {
        Button {
            setExpanded(true)
        } label: {
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        AppColor.background.opacity(0.5),
                        AppColor.background
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 32)
                Text("ещё")
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.blue)
                    .padding(.leading, 4)
                    .background(AppColor.background)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
    }

    private func setExpanded(_ isExpanded: Bool) {
        if animatesExpansion {
            withAnimation {
                self.isExpanded = isExpanded
            }
        } else {
            self.isExpanded = isExpanded
        }
    }

    private func updateAvailableWidth(_ width: CGFloat) {
        guard abs(width - availableWidth) > 0.5 else { return }
        availableWidth = width
        recalculateLineCount()
    }

    private func recalculateLineCount() {
        guard availableWidth > 0, !text.isEmpty else {
            measuredLineCount = 0
            return
        }
        measuredLineCount = renderedLineCount(for: text, width: availableWidth)
    }

    private func renderedLineCount(for text: String, width: CGFloat) -> Int {
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let font = UIFont.systemFont(ofSize: baseFont.pointSize, weight: .medium)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]

        let textRect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        return Int(ceil(textRect.height / font.lineHeight))
    }
}
