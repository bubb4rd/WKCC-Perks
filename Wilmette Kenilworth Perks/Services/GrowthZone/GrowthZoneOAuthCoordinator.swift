import Foundation

struct GrowthZoneOAuthRequest {
    let authorizeURL: URL
    let state: String
    let codeVerifier: String
}

enum GrowthZoneOAuthCoordinator {
    static func makeAuthorizeRequest() -> GrowthZoneOAuthRequest {
        let state = UUID().uuidString
        let nonce = UUID().uuidString
        let codeVerifier = GrowthZonePKCE.generateVerifier()
        let codeChallenge = GrowthZonePKCE.challenge(for: codeVerifier)

        var components = URLComponents(
            url: AppConfig.growthZoneAuthorizeURL,
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: AppConfig.growthZoneOAuthClientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "redirect_uri", value: AppConfig.authCallbackURL.absoluteString),
            URLQueryItem(name: "scope", value: AppConfig.oauthScopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        return GrowthZoneOAuthRequest(
            authorizeURL: components.url!,
            state: state,
            codeVerifier: codeVerifier
        )
    }

    static func parseCallback(
        _ callbackURL: URL,
        expectedState: String
    ) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw AuthError.underlying(GrowthZoneServiceError.invalidResponse)
        }

        let queryItems = components.queryItems ?? []
        let state = queryItems.first(where: { $0.name == "state" })?.value
        let code = queryItems.first(where: { $0.name == "code" })?.value
        let error = queryItems.first(where: { $0.name == "error" })?.value

        if let error, !error.isEmpty {
            throw AuthError.underlying(GrowthZoneServiceError.authorizationFailed(error))
        }

        guard state == expectedState else {
            throw AuthError.underlying(GrowthZoneServiceError.invalidResponse)
        }

        guard let code, !code.isEmpty else {
            throw AuthError.underlying(GrowthZoneServiceError.invalidResponse)
        }

        return code
    }
}

enum GrowthZoneServiceError: LocalizedError {
    case authorizationFailed(String)
    case tokenExchangeFailed
    case memberFetchFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .authorizationFailed(let reason):
            "GrowthZone authorization failed: \(reason)"
        case .tokenExchangeFailed:
            "We couldn't complete sign in. Please try again."
        case .memberFetchFailed:
            "We couldn't load your member profile. Please try again."
        case .invalidResponse:
            "Received an unexpected response from GrowthZone."
        }
    }
}
