import SwiftUI

struct RestrictedAccessView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        ScrollView {
            VStack(spacing: WKCCSpacing.lg) {
                WKCCLogoView(style: .mark, maxWidth: 100)

                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(WKCCColors.warning)

                Text("Membership Not Active")
                    .font(WKCCTypography.title)
                    .foregroundStyle(WKCCColors.textPrimary)

                Text("Your account was found, but your chamber membership is not currently active. Please renew your membership to access member perks.")
                    .font(WKCCTypography.body)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .multilineTextAlignment(.center)

                if let member = authManager.member {
                    VStack(spacing: WKCCSpacing.xs) {
                        Text(member.fullName)
                            .font(WKCCTypography.headline)
                            .foregroundStyle(WKCCColors.textPrimary)
                        Text(member.email)
                            .font(WKCCTypography.callout)
                            .foregroundStyle(WKCCColors.textSecondary)
                    }
                    .padding(WKCCSpacing.md)
                    .frame(maxWidth: .infinity)
                    .wkccCardStyle()
                }

                WKCCPrimaryButton(title: "Visit Chamber Website") {
                    UIApplication.shared.open(AppConfig.chamberWebsiteURL)
                }

                WKCCSecondaryButton(title: "Sign Out") {
                    Task { await authManager.signOut() }
                }
            }
            .padding(WKCCSpacing.lg)
        }
        .wkccPageBackground()
    }
}

#Preview {
    RestrictedAccessView()
        .environment(AuthManager())
}
