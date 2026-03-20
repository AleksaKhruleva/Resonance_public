import SwiftUI

public struct SettingsSection<Content: View>: View {
    
    private let title: String
    private let content: Content
    
    public init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .wixFont(.semibold, color: AppColor.placeholder, size: AppFontSize.caption)
                .padding(.leading)
            
            VStack(spacing: 0) {
                content
            }
            .background(AppColor.placeholder.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
