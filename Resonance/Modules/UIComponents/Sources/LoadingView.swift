import SwiftUI

struct LoadingView: View {
    
    var body: some View {
        ZStack {
            AppBackgroundView().opacity(0.9)
            
            VStack(spacing: 16) {
                ProgressView()
                    .tint(AppColor.blue)
                
                Text("Секундочку...")
                    .wixFont(color: AppColor.blue, size: 18)
            }
        }
        .allowsHitTesting(true)
    }
}

public extension View {
    func loading(_ isPresented: Bool) -> some View {
        self.overlay {
            LoadingView()
                .opacity(isPresented ? 1 : 0)
                .animation(.default, value: isPresented)
        }
    }
}
