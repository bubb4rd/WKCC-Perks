import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            WKCCColors.pageBackground
                .ignoresSafeArea()

            VStack(spacing: WKCCSpacing.lg) {
                WKCCLogoView(style: .stacked, maxWidth: 260)
                    .scaleEffect(isAnimating ? 1.0 : 0.92)
                    .opacity(isAnimating ? 1.0 : 0.6)

                Rectangle()
                    .fill(WKCCColors.accent)
                    .frame(width: 48, height: 3)
                
                VStack(spacing: WKCCSpacing.xs) {
                    Text(AppConfig.appDisplayName.uppercased())
                        .font(WKCCTypography.headline)
                        .foregroundStyle(WKCCColors.primary)
                        .tracking(1)

                }
            }
            .padding(WKCCSpacing.xl)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    SplashView()
}
