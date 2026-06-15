import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        ScrollView {
            VStack(spacing: WKCCSpacing.lg) {
                if let member = authManager.member {
                    memberHeader(member)
                    membershipCard(member)
                }

                NavigationLink {
                    SubmitPromotionView()
                } label: {
                    settingsRow(icon: "megaphone.fill", title: "Submit a Promotion", color: WKCCColors.accent)
                }

                NavigationLink {
                    MemberCardView()
                } label: {
                    settingsRow(icon: "creditcard.fill", title: "Digital Member Card", color: WKCCColors.accent)
                }

                NavigationLink {
                    HelpSupportView()
                } label: {
                    settingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: WKCCColors.primary)
                }

                Button {
                    UIApplication.shared.open(AppConfig.chamberWebsiteURL)
                } label: {
                    settingsRow(icon: "globe", title: "Chamber Website", color: WKCCColors.primary)
                }

                WKCCSecondaryButton(title: "Sign Out") {
                    Task { await authManager.signOut() }
                }
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
        .navigationTitle("Profile")
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func memberHeader(_ member: MemberProfile) -> some View {
        VStack(spacing: WKCCSpacing.sm) {
            ZStack {
                Circle()
                    .fill(WKCCColors.accent.opacity(0.2))
                    .frame(width: 80, height: 80)

                Text(member.firstName.prefix(1) + member.lastName.prefix(1))
                    .font(.title.weight(.semibold))
                    .foregroundStyle(WKCCColors.primary)
            }

            Text(member.fullName)
                .font(WKCCTypography.title)

            Text(member.email)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)

            if let company = member.companyName {
                Text(company)
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(WKCCSpacing.lg)
        .wkccCardStyle()
    }

    private func membershipCard(_ member: MemberProfile) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                Text("Membership Tier")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)

                MembershipTierBadge(tier: member.membershipTier, style: .label)
            }

            Spacer()

            if let since = member.memberSince {
                VStack(alignment: .trailing, spacing: WKCCSpacing.xxs) {
                    Text("Member Since")
                        .font(WKCCTypography.caption)
                        .foregroundStyle(WKCCColors.textSecondary)

                    Text(since.formatted(.dateTime.year().month(.wide)))
                        .font(WKCCTypography.callout)
                        .foregroundStyle(WKCCColors.textPrimary)
                }
            }
        }
        .padding(WKCCSpacing.md)
        .wkccCardStyle()
    }

    private func settingsRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: WKCCSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)

            Text(title)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(WKCCColors.textSecondary)
        }
        .padding(WKCCSpacing.md)
        .wkccCardStyle()
    }
}

#Preview {
    ProfileView()
        .environment(AuthManager())
}
