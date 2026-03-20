import SwiftUI

public struct SettingsToggleRow: View {
    
    private let iconName: String
    private let title: String
    
    @Binding var isOn: Bool

    public init(isOn: Binding<Bool>, iconName: String, title: String) {
        self._isOn = isOn
        self.iconName = iconName
        self.title = title
    }
    
    public var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundStyle(AppColor.blue)
                .fontSize(18)
                .frame(minWidth: 28)
            
            Text(title)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppColor.blue)
                .scaleEffect(0.8)
                .fixedSize()
        }
        .fontWeight(.medium)
        .padding()
    }
}
