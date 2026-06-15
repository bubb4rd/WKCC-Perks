import Foundation
import Observation

@Observable
@MainActor
final class AuthManager {
    private(set) var flowState: AppFlowState = .launching
    private(set) var session: AuthSession?
    private(set) var member: MemberProfile?

    private let authService: any AuthServicing

    init(authService: any AuthServicing = AppDependencies.shared.authService) {
        self.authService = authService
    }

    func bootstrap() async {
        flowState = .launching

        if let restored = await authService.restoreSession(), !restored.isExpired {
            applySession(restored)
        } else {
            KeychainStore.clear()
            flowState = .unauthenticated
        }
    }

    func signIn() async {
        guard flowState != .authenticating else { return }
        flowState = .authenticating

        do {
            let newSession = try await authService.startLogin()
            try KeychainStore.save(newSession)
            applySession(newSession)
        } catch let error as AuthError where error == .cancelled {
            flowState = session == nil ? .unauthenticated : .authenticated
        } catch {
            flowState = .error(error.localizedDescription)
        }
    }

    func signOut() async {
        await authService.signOut()
        KeychainStore.clear()
        session = nil
        member = nil
        flowState = .unauthenticated
    }

    func resetPassword() async {
        await authService.openPasswordReset()
    }

    func dismissError() {
        flowState = session == nil ? .unauthenticated : .authenticated
    }

    private func applySession(_ session: AuthSession) {
        self.session = session
        self.member = session.member

        if session.member.membershipStatus.isEntitled && session.member.entitlements.canViewDeals {
            flowState = .authenticated
        } else {
            flowState = .restrictedMembership
        }
    }
}

extension AuthError: Equatable {
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.cancelled, .cancelled),
             (.invalidCallback, .invalidCallback),
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
