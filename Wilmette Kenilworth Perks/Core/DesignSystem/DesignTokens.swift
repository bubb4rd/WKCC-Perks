import SwiftUI

enum WKCCColors {
    /// Official WKCC blue — #2E3192
    static let primary = Color("WKCCPrimary")
    /// Official WKCC green — #8DC63F
    static let accent = Color("WKCCAccent")
    /// Light grey page background
    static let pageBackground = Color("WKCCPageBackground")
    /// White card and panel background
    static let cardBackground = Color("WKCCCardBackground")
    static let textPrimary = Color("WKCCPrimary")
    static let textSecondary = Color("WKCCPrimary").opacity(0.65)
    static let textOnPrimary = Color.white
    static let success = Color("WKCCAccent")
    static let warning = Color.orange
    static let error = Color.red

    // Legacy aliases used across views
    static let groupedBackground = pageBackground
    static let secondaryBackground = cardBackground
    static let surface = cardBackground
}

enum WKCCSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum WKCCRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let pill: CGFloat = 100
}

enum WKCCTypography {
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    static let title = Font.system(.title2, design: .default).weight(.semibold)
    static let headline = Font.system(.headline, design: .default).weight(.semibold)
    static let sectionTitle = Font.system(.title3, design: .default).weight(.semibold)
    static let body = Font.system(.body, design: .default)
    static let callout = Font.system(.callout, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let captionBold = Font.system(.caption, design: .default).weight(.semibold)
    static let brandCaps = Font.system(.subheadline, design: .default).weight(.semibold)
}

struct WKCCShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: WKCCColors.primary.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

struct WKCCPageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(WKCCColors.pageBackground.ignoresSafeArea())
    }
}

struct WKCCCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(WKCCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: WKCCRadius.lg)
                    .stroke(WKCCColors.primary.opacity(0.08), lineWidth: 1)
            )
            .wkccCardShadow()
    }
}

extension View {
    func wkccCardShadow() -> some View {
        modifier(WKCCShadow())
    }

    func wkccPageBackground() -> some View {
        modifier(WKCCPageBackground())
    }

    func wkccCardStyle() -> some View {
        modifier(WKCCCardStyle())
    }
}
