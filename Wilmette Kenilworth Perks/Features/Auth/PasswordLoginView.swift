import SwiftUI

struct PasswordLoginView: View {
    var initialEmail: String = ""

    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    private var isLoading: Bool {
        authManager.flowState == .authenticating
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
            && !isLoading
    }

    var body: some View {
        ScrollView {
            VStack(spacing: WKCCSpacing.lg) {
                HStack {
                    backButton
                    Spacer()
                }

                VStack(spacing: WKCCSpacing.sm) {
                    WKCCLogoView(style: .mark, maxWidth: 72)

                    Text("Password sign-in")
                        .font(WKCCTypography.largeTitle)
                        .foregroundStyle(WKCCColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Sign in with your chamber email and password.")
                        .font(WKCCTypography.callout)
                        .foregroundStyle(WKCCColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                formCard
            }
            .padding(.horizontal, WKCCSpacing.lg)
            .padding(.top, WKCCSpacing.lg)
            .padding(.bottom, WKCCSpacing.xxl)
        }
        .wkccPageBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if email.isEmpty {
                let seeded = initialEmail.isEmpty ? authManager.pendingEmail : initialEmail
                if !seeded.isEmpty {
                    email = seeded
                }
            }
        }
        .onChange(of: authManager.flowState) { _, newValue in
            if newValue == .confirmingLink {
                dismiss()
            }
        }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .foregroundStyle(WKCCColors.primary)
                .frame(width: 40, height: 40)
                .background(WKCCColors.cardBackground)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(WKCCColors.primary.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel("Back")
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            fieldLabel("Email address")

            TextField("name@business.com", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .padding(WKCCSpacing.md)
                .background(WKCCColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: WKCCRadius.md)
                        .stroke(WKCCColors.primary.opacity(0.12), lineWidth: 1)
                )

            fieldLabel("Password")

            SecureField("Password", text: $password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { signIn() }
                .padding(WKCCSpacing.md)
                .background(WKCCColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: WKCCRadius.md)
                        .stroke(WKCCColors.primary.opacity(0.12), lineWidth: 1)
                )

            if let message = authManager.passwordSignInError, !message.isEmpty {
                Text(message)
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.error)
            }

            WKCCPrimaryButton(
                title: "Sign in",
                isLoading: isLoading
            ) {
                signIn()
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

    private func signIn() {
        guard canSubmit else { return }
        focusedField = nil
        Task {
            await authManager.signInWithPassword(email: email, password: password)
        }
    }
}

#Preview {
    NavigationStack {
        PasswordLoginView()
    }
    .environment(AuthManager())
}
