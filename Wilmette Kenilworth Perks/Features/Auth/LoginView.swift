import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager

    private var isLoading: Bool {
        authManager.flowState == .authenticating
    }

    var body: some View {
        ScrollView {
            VStack(spacing: WKCCSpacing.xl) {
                Spacer(minLength: WKCCSpacing.xxl)

                VStack(spacing: WKCCSpacing.md) {
                    WKCCLogoView(style: .stacked, maxWidth: 240)

                    Text("Member Perks")
                        .font(WKCCTypography.largeTitle)
                        .foregroundStyle(WKCCColors.textPrimary)
                }

                VStack(spacing: WKCCSpacing.sm) {
                    WKCCPrimaryButton(
                        title: "Member Login",
                        isLoading: isLoading
                    ) {
                        Task { await authManager.signIn() }
                    }

                    Button("Forgot Password?") {
                        Task { await authManager.resetPassword() }
                    }
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.primary)
                }

                Text("Use your existing chamber member credentials to sign in.")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: WKCCSpacing.xl)
            }
            .padding(WKCCSpacing.lg)
        }
        .wkccPageBackground()
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
