import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var email = ""
    @State private var codeDigits = Array(repeating: "", count: 6)
    @State private var resendCooldown = 0
    @FocusState private var focusedDigitIndex: Int?

    private var isLoading: Bool {
        authManager.flowState == .authenticating
    }

    private var currentStep: AccountLinkStep {
        if authManager.flowState == .confirmingLink {
            return .confirm
        }
        if authManager.isCodeSent {
            return .verify
        }
        return .connect
    }

    private var code: String {
        codeDigits.joined()
    }

    private var maskedEmail: String {
        Self.maskEmail(authManager.pendingEmail)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: WKCCSpacing.lg) {
                if currentStep != .connect {
                    HStack {
                        backButton
                        Spacer()
                    }
                }

                header

                WKCCStepProgressBar(
                    labels: ["Connect", "Verify", "Confirm"],
                    currentIndex: currentStep.rawValue
                )
                    .padding(.top, WKCCSpacing.xs)

                Group {
                    switch currentStep {
                    case .connect:
                        connectStep
                    case .verify:
                        verifyStep
                    case .confirm:
                        confirmStep
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: currentStep)
            }
            .padding(.horizontal, WKCCSpacing.lg)
            .padding(.top, WKCCSpacing.lg)
            .padding(.bottom, WKCCSpacing.xxl)
        }
        .wkccPageBackground()
        .onChange(of: authManager.isCodeSent) { _, sent in
            if sent {
                codeDigits = Array(repeating: "", count: 6)
                focusedDigitIndex = 0
                startResendCooldown()
            }
        }
    }

    private var backButton: some View {
        Button {
            goBack()
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

    private func goBack() {
        switch currentStep {
        case .verify:
            codeDigits = Array(repeating: "", count: 6)
            resendCooldown = 0
            focusedDigitIndex = nil
            email = authManager.pendingEmail.isEmpty ? email : authManager.pendingEmail
            authManager.goBackFromVerify()
        case .confirm:
            codeDigits = Array(repeating: "", count: 6)
            focusedDigitIndex = 0
            authManager.goBackFromConfirm()
        case .connect:
            break
        }
    }

    private var header: some View {
        VStack(spacing: WKCCSpacing.sm) {
            WKCCLogoView(style: .mark, maxWidth: 72)

            Text(currentStep.title)
                .font(WKCCTypography.largeTitle)
                .foregroundStyle(WKCCColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(currentStep.subtitle(maskedEmail: maskedEmail))
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Steps

    private var connectStep: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            fieldLabel("Email address")

            TextField("name@business.com", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(WKCCSpacing.md)
                .background(WKCCColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: WKCCRadius.md)
                        .stroke(WKCCColors.primary.opacity(0.12), lineWidth: 1)
                )

            Text("Use the email on your chamber membership record.")
                .font(WKCCTypography.caption)
                .foregroundStyle(WKCCColors.textSecondary)

            WKCCPrimaryButton(
                title: "Continue",
                isLoading: isLoading
            ) {
                Task {
                    await authManager.requestCode(email: email)
                }
            }
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
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

    private var verifyStep: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            fieldLabel("Verification code")

            HStack(spacing: WKCCSpacing.xs) {
                ForEach(0..<6, id: \.self) { index in
                    TextField("", text: $codeDigits[index])
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(.title2, design: .monospaced).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(WKCCColors.pageBackground)
                        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: WKCCRadius.md)
                                .stroke(
                                    focusedDigitIndex == index
                                        ? WKCCColors.primary
                                        : WKCCColors.primary.opacity(0.12),
                                    lineWidth: focusedDigitIndex == index ? 2 : 1
                                )
                        )
                        .focused($focusedDigitIndex, equals: index)
                        .onChange(of: codeDigits[index]) { _, newValue in
                            handleDigitChange(at: index, newValue: newValue)
                        }
                }
            }

            if AppConfig.useMockAuth {
                Text("Test mode: no email is sent. Use a chamber membership email and code \(AppConfig.mockLoginCode).")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)
            }

            HStack {
                Spacer()

                Button {
                    Task {
                        await authManager.resendCode()
                    }
                } label: {
                    Text(resendCooldown > 0 ? "Resend in \(resendCooldown)s" : "Resend code")
                        .font(WKCCTypography.callout.weight(.semibold))
                        .foregroundStyle(
                            resendCooldown > 0 || isLoading
                                ? WKCCColors.textSecondary
                                : WKCCColors.primary
                        )
                }
                .disabled(resendCooldown > 0 || isLoading)
            }

            WKCCPrimaryButton(
                title: "Verify email",
                isLoading: isLoading
            ) {
                Task { await authManager.verifyCode(code) }
            }
            .disabled(code.count != 6 || isLoading)
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

    private var confirmStep: some View {
        let profile = authManager.pendingConfirmationSession?.member ?? authManager.member

        return VStack(spacing: WKCCSpacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(WKCCColors.accent)

            Text("Does this look correct?")
                .font(WKCCTypography.title)
                .foregroundStyle(WKCCColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Confirm your chamber membership details to finish linking WKCC Perks.")
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: WKCCSpacing.md) {
                confirmationRow(label: "Business", value: profile?.companyName ?? "Unavailable")
                Divider().overlay(WKCCColors.primary.opacity(0.08))
                confirmationRow(label: "Email", value: profile?.email ?? authManager.pendingEmail)
                Divider().overlay(WKCCColors.primary.opacity(0.08))
                confirmationRow(label: "Name", value: profile?.fullName.trimmingCharacters(in: .whitespaces) ?? "Unavailable")
            }
            .padding(WKCCSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WKCCColors.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))

            WKCCPrimaryButton(title: "Proceed to WKCC Perks") {
                authManager.confirmLinkedAccount()
            }
        }
        .padding(WKCCSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(WKCCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: WKCCRadius.xl)
                .stroke(WKCCColors.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(WKCCTypography.captionBold)
            .foregroundStyle(WKCCColors.textSecondary)
    }

    private func confirmationRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
            Text(label.uppercased())
                .font(WKCCTypography.captionBold)
                .foregroundStyle(WKCCColors.textSecondary)
                .tracking(0.4)

            Text(value)
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleDigitChange(at index: Int, newValue: String) {
        let filtered = newValue.filter(\.isNumber)

        if filtered.isEmpty {
            codeDigits[index] = ""
            if index > 0 {
                focusedDigitIndex = index - 1
            }
            return
        }

        if filtered.count > 1 {
            // Paste support: distribute digits across boxes.
            let chars = Array(filtered.prefix(6 - index))
            for offset in 0..<chars.count {
                codeDigits[index + offset] = String(chars[offset])
            }
            focusedDigitIndex = min(index + chars.count, 5)
            return
        }

        codeDigits[index] = String(filtered.prefix(1))
        if index < 5 {
            focusedDigitIndex = index + 1
        } else {
            focusedDigitIndex = nil
        }
    }

    private func startResendCooldown() {
        resendCooldown = 30
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                resendCooldown -= 1
            }
        }
    }

    private static func maskEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2, let first = parts[0].first else { return email }
        return "\(first)********@\(parts[1])"
    }
}

// MARK: - Progress

private enum AccountLinkStep: Int, CaseIterable {
    case connect = 0
    case verify = 1
    case confirm = 2

    var title: String {
        switch self {
        case .connect: "Connect account"
        case .verify: "Verify email"
        case .confirm: "Account linked"
        }
    }

    func subtitle(maskedEmail: String) -> String {
        switch self {
        case .connect:
            "Link your chamber membership email to WKCC Perks."
        case .verify:
            "Enter the 6-digit code sent to \(maskedEmail)."
        case .confirm:
            "Review your membership details, then continue."
        }
    }
}

#Preview("Connect") {
    LoginView()
        .environment(AuthManager())
}
