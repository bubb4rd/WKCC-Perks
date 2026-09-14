import SwiftUI

/// Lets an OTP-verified member create or replace their password sign-in,
/// so future sign-ins can skip email OTP if they choose.
struct SetPasswordView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSave = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case password
        case confirm
    }

    private var trimmedPassword: String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        trimmedPassword.count >= 8
            && password == confirmPassword
            && !isSaving
    }

    private var isReset: Bool {
        authManager.member?.hasPassword == true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: WKCCSpacing.lg) {
                VStack(spacing: WKCCSpacing.sm) {
                    WKCCLogoView(style: .mark, maxWidth: 72)

                    Text(didSave ? "Password saved" : (isReset ? "Reset your password" : "Create a password"))
                        .font(WKCCTypography.largeTitle)
                        .foregroundStyle(WKCCColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(
                        didSave
                            ? "You can now sign in with your email and this password, or continue using email codes."
                            : (isReset
                                ? "Set a new password to replace your current one."
                                : "Set a password so you can sign in faster next time, without waiting for an email code.")
                    )
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                if didSave {
                    WKCCPrimaryButton(title: "Done") {
                        dismiss()
                    }
                } else {
                    formCard
                }
            }
            .padding(.horizontal, WKCCSpacing.lg)
            .padding(.top, WKCCSpacing.lg)
            .padding(.bottom, WKCCSpacing.xxl)
        }
        .wkccPageBackground()
        .navigationTitle("Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            fieldLabel("New password")

            SecureField("At least 8 characters", text: $password)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit { focusedField = .confirm }
                .padding(WKCCSpacing.md)
                .background(WKCCColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: WKCCRadius.md)
                        .stroke(WKCCColors.primary.opacity(0.12), lineWidth: 1)
                )

            fieldLabel("Confirm password")

            SecureField("Re-enter password", text: $confirmPassword)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirm)
                .submitLabel(.go)
                .onSubmit { save() }
                .padding(WKCCSpacing.md)
                .background(WKCCColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: WKCCRadius.md)
                        .stroke(WKCCColors.primary.opacity(0.12), lineWidth: 1)
                )

            if !confirmPassword.isEmpty && password != confirmPassword {
                Text("Passwords don't match.")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.error)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.error)
            }

            WKCCPrimaryButton(
                title: "Save password",
                isLoading: isSaving
            ) {
                save()
            }
            .disabled(!canSubmit)
            .padding(.top, WKCCSpacing.sm)
        }
        .padding(WKCCSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WKCCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: WKCCRadius.xl)
                .stroke(WKCCColors.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(WKCCTypography.captionBold)
            .foregroundStyle(WKCCColors.textSecondary)
    }

    private func save() {
        guard canSubmit else { return }
        focusedField = nil
        errorMessage = nil
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await authManager.setPassword(trimmedPassword)
                didSave = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        SetPasswordView()
    }
    .environment(AuthManager())
}
