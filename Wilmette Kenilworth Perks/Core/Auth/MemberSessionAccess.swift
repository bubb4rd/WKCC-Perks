import Foundation

/// Resolves a usable member access token, refreshing when expired or near expiry.
enum MemberSessionAccess {
    /// Refresh when fewer than this many seconds remain on the access token.
    static let refreshSkewSeconds: TimeInterval = 5 * 60

    enum AccessError: LocalizedError {
        case missingSession
        case refreshFailed

        var errorDescription: String? {
            switch self {
            case .missingSession, .refreshFailed:
                "Your session has expired. Please sign in again."
            }
        }
    }

    /// Returns a valid access token, refreshing proactively when needed.
    /// Pass `forceRefresh: true` after a 401 to rotate immediately and retry once.
    static func accessToken(forceRefresh: Bool = false) async throws -> String {
        guard var session = KeychainStore.loadSession() else {
            throw AccessError.missingSession
        }

        let shouldRefresh = forceRefresh
            || session.isExpired
            || session.isExpiring(within: refreshSkewSeconds)

        if shouldRefresh {
            do {
                session = try await refresh(session)
                try KeychainStore.save(session)
                NotificationCenter.default.post(name: .memberSessionDidRefresh, object: nil)
            } catch {
                if forceRefresh || session.isExpired {
                    KeychainStore.clear()
                    NotificationCenter.default.post(name: .memberSessionDidExpire, object: nil)
                    throw AccessError.refreshFailed
                }
                // Near-expiry refresh failed but token may still work — fall through.
            }
        }

        guard !session.accessToken.isEmpty else {
            throw AccessError.missingSession
        }
        return session.accessToken
    }

    private static func refresh(_ session: AuthSession) async throws -> AuthSession {
        guard let refreshToken = session.refreshToken, !refreshToken.isEmpty else {
            throw AccessError.refreshFailed
        }

        let url = AppConfig.memberAuthBaseURL.appending(path: "refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        struct Body: Encodable { let refreshToken: String }
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(Body(refreshToken: refreshToken))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AccessError.refreshFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.parseISO8601Date(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(value)"
            )
        }

        let dto = try decoder.decode(RefreshSessionDTO.self, from: data)
        return try dto.toAuthSession()
    }

    private static func parseISO8601Date(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

private struct RefreshSessionDTO: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let member: RefreshMemberDTO

    func toAuthSession() throws -> AuthSession {
        AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            member: try member.toMemberProfile()
        )
    }
}

private struct RefreshMemberDTO: Decodable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let phone: String?
    let address: String?
    let membershipTier: String
    let membershipStatus: String
    let companyId: String?
    let companyName: String?
    let companyLogoURL: String?
    let memberSince: Date?
    let entitlements: RefreshEntitlementsDTO

    func toMemberProfile() throws -> MemberProfile {
        MemberProfile(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            address: address,
            membershipTier: MembershipTier(rawValue: membershipTier) ?? .basic,
            membershipStatus: MembershipStatus(rawValue: membershipStatus) ?? .inactive,
            companyId: companyId,
            companyName: companyName,
            companyLogoURL: companyLogoURL.flatMap(URL.init(string:)),
            memberSince: memberSince,
            entitlements: MemberEntitlements(
                canViewDeals: entitlements.canViewDeals,
                canSaveDeals: entitlements.canSaveDeals,
                canRedeemDeals: entitlements.canRedeemDeals,
                isChamberAdmin: entitlements.isChamberAdmin
            )
        )
    }
}

private struct RefreshEntitlementsDTO: Decodable {
    let canViewDeals: Bool
    let canSaveDeals: Bool
    let canRedeemDeals: Bool
    let isChamberAdmin: Bool
}
