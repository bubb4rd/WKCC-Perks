import AuthenticationServices
import Foundation
import UIKit

/// GrowthZone login via ASWebAuthenticationSession.
/// Swap in real callback URL handling once chamber provides SSO configuration.
final class GrowthZoneAuthService: NSObject, AuthServicing, ASWebAuthenticationPresentationContextProviding {
    private var authSession: ASWebAuthenticationSession?

    func startLogin() async throws -> AuthSession {
        try await withCheckedThrowingContinuation { continuation in
            var resumed = false

            let session = ASWebAuthenticationSession(
                url: AppConfig.growthZoneLoginURL,
                callbackURLScheme: AppConfig.authCallbackScheme
            ) { callbackURL, error in
                guard !resumed else { return }
                resumed = true

                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(throwing: AuthError.cancelled)
                    return
                }

                if let error {
                    continuation.resume(throwing: AuthError.underlying(error))
                    return
                }

                guard callbackURL != nil else {
                    continuation.resume(throwing: AuthError.invalidCallback)
                    return
                }

                // Placeholder until real token exchange is configured.
                continuation.resume(returning: MockData.sampleSession)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session

            if !session.start() {
                resumed = true
                continuation.resume(throwing: AuthError.invalidCallback)
            }
        }
    }

    func restoreSession() async -> AuthSession? {
        KeychainStore.loadSession()
    }

    func signOut() async {
        KeychainStore.clear()
    }

    func openPasswordReset() async {
        await MainActor.run {
            UIApplication.shared.open(AppConfig.growthZonePasswordResetURL)
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
