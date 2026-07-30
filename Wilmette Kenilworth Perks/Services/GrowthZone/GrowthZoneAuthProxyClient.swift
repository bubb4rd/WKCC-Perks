import Foundation

struct GrowthZoneTokenBundle: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let idToken: String?
    let tokenType: String?

    var expiresAt: Date? {
        guard let expiresIn else { return nil }
        return Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}

struct GrowthZoneAuthProxyClient {
    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = AppConfig.authProxyBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func exchangeCode(
        code: String,
        codeVerifier: String,
        redirectURI: String = AppConfig.authCallbackURL.absoluteString
    ) async throws -> GrowthZoneTokenBundle {
        try await post(
            path: "token",
            body: [
                "code": code,
                "codeVerifier": codeVerifier,
                "redirectUri": redirectURI,
            ]
        )
    }

    func refresh(refreshToken: String) async throws -> GrowthZoneTokenBundle {
        try await post(
            path: "refresh",
            body: ["refreshToken": refreshToken]
        )
    }

    private func post(path: String, body: [String: String]) async throws -> GrowthZoneTokenBundle {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GrowthZoneServiceError.tokenExchangeFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GrowthZoneServiceError.tokenExchangeFailed
        }

        do {
            return try JSONDecoder().decode(GrowthZoneTokenBundle.self, from: data)
        } catch {
            throw GrowthZoneServiceError.invalidResponse
        }
    }
}
