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
                        .foregroundStyle(WKCCColors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    if let company = member.companyName {
                        Text(company)
                            .font(WKCCTypography.callout)
                            .foregroundStyle(WKCCColors.textSecondary)
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
                    .foregroundStyle(WKCCColors.textSecondary)

                Spacer(minLength: WKCCSpacing.sm)

                Text(authManager.member?.id ?? "—")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(WKCCColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(WKCCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: WKCCRadius.xl)
                .stroke(WKCCColors.primary.opacity(0.12), lineWidth: 1)
        )
        .wkccCardShadow()
    }
}

#Preview {
    NavigationStack {
        MemberCardView()
            .environment(AuthManager())
    }
}
