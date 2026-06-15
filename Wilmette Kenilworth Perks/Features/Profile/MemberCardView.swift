import SwiftUI

struct MemberCardView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        ScrollView {
            VStack(spacing: WKCCSpacing.lg) {
                Text("Show this screen to redeem member perks at participating businesses.")
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .multilineTextAlignment(.center)

                memberCard

                Text("This digital card serves as proof of your active WKCC membership.")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(WKCCSpacing.lg)
        }
        .wkccPageBackground()
        .navigationTitle("Member Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var memberCard: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            HStack(alignment: .top) {
                WKCCLogoView(style: .mark, maxWidth: 64)

                Spacer(minLength: WKCCSpacing.sm)

                Text("MEMBER")
                    .font(WKCCTypography.brandCaps)
                    .foregroundStyle(WKCCColors.accent)
                    .tracking(1)
            }

            if let member = authManager.member {
                VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                    Text(member.fullName.uppercased())
                        .font(.system(.title3, design: .default).weight(.bold))
                        .foregroundStyle(WKCCColors.textOnPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    if let company = member.companyName {
                        Text(company)
                            .font(WKCCTypography.callout)
                            .foregroundStyle(WKCCColors.textOnPrimary.opacity(0.85))
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                    }

                    Text(member.membershipTier.displayName.uppercased())
                        .font(WKCCTypography.captionBold)
                        .foregroundStyle(WKCCColors.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: WKCCSpacing.xs)

            Rectangle()
                .fill(WKCCColors.accent)
                .frame(height: 2)

            HStack(alignment: .firstTextBaseline) {
                Text("Member ID")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textOnPrimary.opacity(0.7))

                Spacer(minLength: WKCCSpacing.sm)

                Text(authManager.member?.id ?? "—")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(WKCCColors.textOnPrimary.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(WKCCColors.primary)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl))
        .wkccCardShadow()
    }
}

#Preview {
    NavigationStack {
        MemberCardView()
            .environment(AuthManager())
    }
}
