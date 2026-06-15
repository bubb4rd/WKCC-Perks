import SwiftUI

struct HelpSupportView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                WKCCLogoView(style: .mark, maxWidth: 72)
                    .frame(maxWidth: .infinity)

                faqSection

                contactSection

                linksSection
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            Text("Frequently Asked Questions")
                .font(WKCCTypography.sectionTitle)
                .foregroundStyle(WKCCColors.textPrimary)

            faqItem(
                question: "How do I redeem a perk?",
                answer: "Open the deal detail screen and follow the redemption instructions. Most perks require you to show this app or your digital member card at the business."
            )

            faqItem(
                question: "Who can use this app?",
                answer: "This app is for current \(AppConfig.chamberName) members. Sign in with your existing chamber credentials."
            )

            faqItem(
                question: "What if my membership has expired?",
                answer: "Renew your membership through the chamber website at wilmettekenilworth.com. Once renewed, sign out and sign back in to refresh your access."
            )
        }
    }

    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
            Text(question)
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            Text(answer)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wkccCardStyle()
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("Contact the Chamber")
                .font(WKCCTypography.sectionTitle)
                .foregroundStyle(WKCCColors.textPrimary)

            Text(AppConfig.chamberName)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)

            Button {
                UIApplication.shared.open(AppConfig.chamberMapsURL)
            } label: {
                contactRow(icon: "mappin.and.ellipse", label: AppConfig.chamberFullAddress)
            }

            Button {
                if let url = AppConfig.supportEmailURL {
                    UIApplication.shared.open(url)
                }
            } label: {
                contactRow(icon: "envelope.fill", label: AppConfig.supportEmail)
            }

            Button {
                if let url = AppConfig.supportPhoneDialURL {
                    UIApplication.shared.open(url)
                }
            } label: {
                contactRow(icon: "phone.fill", label: AppConfig.supportPhone)
            }
        }
    }

    private func contactRow(icon: String, label: String) -> some View {
        HStack(alignment: .top, spacing: WKCCSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(WKCCColors.accent)
                .frame(width: 28)

            Text(label)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(WKCCColors.textSecondary)
                .padding(.top, 2)
        }
        .padding(WKCCSpacing.md)
        .wkccCardStyle()
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("Useful Links")
                .font(WKCCTypography.sectionTitle)
                .foregroundStyle(WKCCColors.textPrimary)

            Button {
                UIApplication.shared.open(AppConfig.chamberWebsiteURL)
            } label: {
                contactRow(icon: "globe", label: AppConfig.chamberWebsiteURL.absoluteString)
            }

            Button {
                UIApplication.shared.open(AppConfig.growthZonePasswordResetURL)
            } label: {
                contactRow(icon: "key.fill", label: "Reset Password")
            }
        }
    }
}

#Preview {
    NavigationStack {
        HelpSupportView()
    }
}
