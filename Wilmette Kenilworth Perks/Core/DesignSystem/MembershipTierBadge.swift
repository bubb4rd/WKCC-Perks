import SwiftUI

struct MembershipTierBadge: View {
    let tier: MembershipTier
    var style: Style = .filled

    enum Style {
        case filled
        case compact
        case label
    }

    var body: some View {
        Text(tier.displayName)
            .font(labelFont)
            .foregroundStyle(labelForegroundColor)
            .modifier(BadgeBackgroundModifier(style: style, backgroundColor: backgroundColor))
    }

    private var labelFont: Font {
        switch style {
        case .label:
            WKCCTypography.headline
        case .compact:
            WKCCTypography.captionBold
        case .filled:
            WKCCTypography.callout
        }
    }

    private var labelForegroundColor: Color {
        style == .label ? tier.labelColor : foregroundColor
    }

    private var foregroundColor: Color {
        switch tier {
        case .platinum, .gold:
            WKCCColors.textOnPrimary
        default:
            WKCCColors.primary
        }
    }

    private var backgroundColor: Color {
        switch tier {
        case .nonProfit:
            WKCCColors.accent.opacity(0.28)
        case .basic:
            WKCCColors.primary.opacity(0.1)
        case .silver:
            Color(white: 0.82)
        case .gold:
            Color(red: 0.79, green: 0.62, blue: 0.16)
        case .platinum:
            WKCCColors.primary
        case .municipality:
            WKCCColors.accent.opacity(0.35)
        }
    }
}

private extension MembershipTier {
    var labelColor: Color {
        switch self {
        case .nonProfit, .municipality:
            WKCCColors.accent
        case .basic:
            WKCCColors.primary
        case .silver:
            Color(red: 0.45, green: 0.48, blue: 0.52)
        case .gold:
            Color(red: 0.72, green: 0.55, blue: 0.12)
        case .platinum:
            WKCCColors.primary
        }
    }
}

private struct BadgeBackgroundModifier: ViewModifier {
    let style: MembershipTierBadge.Style
    let backgroundColor: Color

    func body(content: Content) -> some View {
        switch style {
        case .label:
            content
        case .compact:
            content
                .padding(.horizontal, WKCCSpacing.sm)
                .padding(.vertical, WKCCSpacing.xs)
                .background(backgroundColor)
                .clipShape(Capsule())
        case .filled:
            content
                .padding(.horizontal, WKCCSpacing.md)
                .padding(.vertical, WKCCSpacing.sm)
                .background(backgroundColor)
                .clipShape(Capsule())
        }
    }
}
