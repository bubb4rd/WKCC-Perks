import SwiftUI

enum WKCCLogoStyle {
    case stacked
    case mark
}

struct WKCCLogoView: View {
    var style: WKCCLogoStyle = .stacked
    var maxWidth: CGFloat = 220

    var body: some View {
        Image(style == .stacked ? "WKCCLogoStacked" : "WKCCLogo")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: maxWidth)
            .background(Color.clear)
            .accessibilityLabel(AppConfig.chamberName)
    }
}

#Preview {
    VStack(spacing: 32) {
        WKCCLogoView(style: .stacked)
        WKCCLogoView(style: .mark, maxWidth: 120)
    }
    .padding()
    .wkccPageBackground()
}
