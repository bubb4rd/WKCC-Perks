import AuthenticationServices
import Foundation
import UIKit

/// Legacy GrowthZone OAuth client. Not wired into AppDependencies.
/// Retained for reference only; primary auth is email OTP via MemberAuthService.
final class GrowthZoneAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var authSession: ASWebAuthenticationSession?
    private let proxyClient: GrowthZoneAuthProxyClient
    private let memberAPIClient: GrowthZoneMemberAPIClient

    init(
        proxyClient: GrowthZoneAuthProxyClient = GrowthZoneAuthProxyClient(),
        memberAPIClient: GrowthZoneMemberAPIClient = GrowthZoneMemberAPIClient()
    ) {
        self.proxyClient = proxyClient
        self.memberAPIClient = memberAPIClient
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
