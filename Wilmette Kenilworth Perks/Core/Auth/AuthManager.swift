import Foundation
import Observation

@Observable
@MainActor
final class AuthManager {
    private(set) var flowState: AppFlowState = .launching
    private(set) var session: AuthSession?
    private(set) var member: MemberProfile?
    private(set) var pendingEmail: String = ""
    private(set) var isCodeSent = false
    /// Session awaiting first-time confirmation before entering the app.
    private(set) var pendingConfirmationSession: AuthSession?

    private let authService: any AuthServicing

    init(authService: any AuthServicing = AppDependencies.shared.authService) {
        self.authService = authService
    }

    func bootstrap() async {
        flowState = .launching

        if let restored = await authService.restoreSession() {
            applySession(restored)
        } else {
            KeychainStore.clear()
            flowState = .unauthenticated
        }
    }

    func requestCode(email: String) async {
        guard flowState != .authenticating else { return }
        flowState = .authenticating
        pendingEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingConfirmationSession = nil

        do {
            try await authService.requestLoginCode(email: pendingEmail)
            isCodeSent = true
            flowState = .unauthenticated
        } catch {
            isCodeSent = false
            flowState = .error(error.localizedDescription)
        }
    }

    func verifyCode(_ code: String) async {
        guard flowState != .authenticating else { return }
        flowState = .authenticating

        do {
            let result = try await authService.verifyLoginCode(
                email: pendingEmail,
                code: code
            )
            isCodeSent = false

            if result.isFirstLink {
                pendingConfirmationSession = result.session
                member = result.session.member
                flowState = .confirmingLink
            } else {
                try KeychainStore.save(result.session)
                pendingConfirmationSession = nil
                applySession(result.session)
            }
        } catch {
            flowState = .error(error.localizedDescription)
        }
    }

    func confirmLinkedAccount() {
        guard let pending = pendingConfirmationSession else { return }

        do {
            try KeychainStore.save(pending)
            pendingConfirmationSession = nil
            isCodeSent = false
            applySession(pending)
        } catch {
            flowState = .error(error.localizedDescription)
        }
    }

    func resendCode() async {
        guard !pendingEmail.isEmpty else { return }
        await requestCode(email: pendingEmail)
    }

    /// Verify → Connect (keeps typed email in the form; clears OTP state).
    func goBackFromVerify() {
        isCodeSent = false
        pendingConfirmationSession = nil
        flowState = .unauthenticated
    }

    /// Confirm → Verify (keeps email; clears pending confirmation session).
    func goBackFromConfirm() {
        pendingConfirmationSession = nil
        isCodeSent = true
        flowState = .unauthenticated
    }

    func returnToEmailEntry() {
        isCodeSent = false
        pendingEmail = ""
        pendingConfirmationSession = nil
        if case .error = flowState {
            flowState = .unauthenticated
        } else if flowState == .confirmingLink {
            flowState = .unauthenticated
        }
    }

    func signOut() async {
        await PushNotificationManager.shared.stopAndUnregister()
        await authService.signOut()
        KeychainStore.clear()
        session = nil
        member = nil
        pendingEmail = ""
        isCodeSent = false
        pendingConfirmationSession = nil
        flowState = .unauthenticated
    }

    func dismissError() {
        if session != nil {
            applySession(session!)
        } else if pendingConfirmationSession != nil {
            flowState = .confirmingLink
        } else {
            flowState = .unauthenticated
        }
    }

    func uploadCompanyLogo(imageData: Data, contentType: String = "image/jpeg") async throws {
        let updatedMember = try await authService.uploadCompanyLogo(
            imageData: imageData,
            contentType: contentType
        )

        guard let current = session else {
            member = updatedMember
            NotificationCenter.default.post(name: .businessLogoDidChange, object: nil)
            return
        }

        let updatedSession = AuthSession(
            accessToken: current.accessToken,
            refreshToken: current.refreshToken,
            expiresAt: current.expiresAt,
            member: updatedMember
        )
        try KeychainStore.save(updatedSession)
        applySession(updatedSession)
        NotificationCenter.default.post(name: .businessLogoDidChange, object: nil)
    }

    var isChamberAdmin: Bool {
        member?.entitlements.isChamberAdmin == true
    }

    /// Sync in-memory session after a background token refresh wrote Keychain.
    func syncSessionFromKeychain() {
        guard let stored = KeychainStore.loadSession() else { return }
        applySession(stored)
    }

    /// Clear local auth after a forced refresh failure cleared Keychain.
    func handleSessionExpiredFromKeychain() {
        session = nil
        member = nil
        pendingEmail = ""
        isCodeSent = false
        pendingConfirmationSession = nil
        flowState = .unauthenticated
    }

    private func applySession(_ session: AuthSession) {
        self.session = session
        self.member = session.member

        if session.member.membershipStatus.isEntitled && session.member.entitlements.canViewDeals {
            flowState = .authenticated
            PushNotificationManager.shared.startIfNeeded()
        } else {
            flowState = .restrictedMembership
        }
    }
}

extension AuthError: Equatable {
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.cancelled, .cancelled),
             (.invalidCode, .invalidCode),
             (.codeExpired, .codeExpired),
             (.rateLimited, .rateLimited),
             (.sessionExpired, .sessionExpired),
             (.membershipInactive, .membershipInactive):
            true
        case (.underlying(let l), .underlying(let r)):
            l.localizedDescription == r.localizedDescription
        default:
            false
        }
    }
}
