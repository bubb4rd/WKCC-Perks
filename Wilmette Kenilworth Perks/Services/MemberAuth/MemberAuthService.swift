import Foundation

/// Backend-first email OTP auth against the Supabase `member-auth` edge function.
final class MemberAuthService: AuthServicing {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL = AppConfig.memberAuthBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = fractional.date(from: value) ?? plain.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(value)"
            )
        }
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func requestLoginCode(email: String) async throws {
        let normalized = Self.normalizeEmail(email)
        guard normalized.contains("@") else {
            throw AuthError.underlying(NSError(
                domain: "MemberAuth",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Enter a valid email address."]
            ))
        }

        struct Body: Encodable { let email: String }
        _ = try await post(path: "request-code", body: Body(email: normalized), as: GenericOK.self)
    }

    func verifyLoginCode(email: String, code: String) async throws -> LoginResult {
        let normalized = Self.normalizeEmail(email)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        struct Body: Encodable {
            let email: String
            let code: String
        }

        let response = try await post(
            path: "verify-code",
            body: Body(email: normalized, code: trimmedCode),
            as: SessionDTO.self
        )
        return try response.toLoginResult()
    }

    func restoreSession() async -> AuthSession? {
        guard var stored = KeychainStore.loadSession() else { return nil }

        if stored.isExpired || stored.isExpiring(within: MemberSessionAccess.refreshSkewSeconds) {
            do {
                stored = try await refreshSession(stored)
                try KeychainStore.save(stored)
            } catch {
                if stored.isExpired {
                    KeychainStore.clear()
                    return nil
                }
                // Near-expiry refresh failed; keep existing token for now.
            }
        }

        return stored
    }

    func refreshSession(_ session: AuthSession) async throws -> AuthSession {
        guard let refreshToken = session.refreshToken, !refreshToken.isEmpty else {
            throw AuthError.sessionExpired
        }

        struct Body: Encodable { let refreshToken: String }
        let response = try await post(
            path: "refresh",
            body: Body(refreshToken: refreshToken),
            as: SessionDTO.self
        )
        return try response.toAuthSession()
    }

    func signOut() async {
        let refreshToken = KeychainStore.loadSession()?.refreshToken
        if let refreshToken, !refreshToken.isEmpty {
            struct Body: Encodable { let refreshToken: String }
            _ = try? await post(
                path: "logout",
                body: Body(refreshToken: refreshToken),
                as: GenericOK.self
            )
        }
        KeychainStore.clear()
    }

    func uploadCompanyLogo(imageData: Data, contentType: String) async throws -> MemberProfile {
        struct Body: Encodable {
            let imageBase64: String
            let contentType: String
        }

        struct Response: Decodable {
            let member: MemberDTO
        }

        let body = Body(
            imageBase64: imageData.base64EncodedString(),
            contentType: contentType
        )

        let response: Response
        do {
            let accessToken = try await MemberSessionAccess.accessToken()
            response = try await postAuthed(
                path: "company-logo",
                accessToken: accessToken,
                body: body,
                as: Response.self
            )
        } catch AuthError.sessionExpired {
            let accessToken = try await MemberSessionAccess.accessToken(forceRefresh: true)
            response = try await postAuthed(
                path: "company-logo",
                accessToken: accessToken,
                body: body,
                as: Response.self
            )
        }

        let member = try response.member.toMemberProfile()
        guard let stored = KeychainStore.loadSession() else {
            return member
        }
        let updatedSession = AuthSession(
            accessToken: stored.accessToken,
            refreshToken: stored.refreshToken,
            expiresAt: stored.expiresAt,
            member: member
        )
        try KeychainStore.save(updatedSession)
        return member
    }

    // MARK: - Networking

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        as: Response.Type
    ) async throws -> Response {
        try await post(
            path: path,
            accessToken: AppConfig.supabaseAnonKey,
            body: body,
            as: Response.self
        )
    }

    private func postAuthed<Body: Encodable, Response: Decodable>(
        path: String,
        accessToken: String,
        body: Body,
        as: Response.Type
    ) async throws -> Response {
        try await post(
            path: path,
            accessToken: accessToken,
            body: body,
            as: Response.self
        )
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        accessToken: String,
        body: Body,
        as: Response.Type
    ) async throws -> Response {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.underlying(URLError(.badServerResponse))
        }

        if (200..<300).contains(http.statusCode) {
            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw AuthError.underlying(error)
            }
        }

        throw mapHTTPError(
            statusCode: http.statusCode,
            data: data,
            isAuthenticatedRequest: accessToken != AppConfig.supabaseAnonKey
        )
    }

    private func mapHTTPError(
        statusCode: Int,
        data: Data,
        isAuthenticatedRequest: Bool
    ) -> AuthError {
        let message = (try? decoder.decode(APIError.self, from: data))?.error

        switch statusCode {
        case 401:
            if isAuthenticatedRequest {
                return .sessionExpired
            }
            if let message, message.lowercased().contains("expired") {
                return .codeExpired
            }
            return .invalidCode
        case 403:
            return .membershipInactive
        case 429:
            return .rateLimited
        default:
            return .underlying(NSError(
                domain: "MemberAuth",
                code: statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: message ?? "Sign in failed. Please try again."
                ]
            ))
        }
    }

    private static func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

// MARK: - DTOs

private struct GenericOK: Decodable {
    let ok: Bool?
    let message: String?
}

private struct APIError: Decodable {
    let error: String?
}

private struct SessionDTO: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let member: MemberDTO
    let isFirstLink: Bool?

    func toAuthSession() throws -> AuthSession {
        AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            member: try member.toMemberProfile()
        )
    }

    func toLoginResult() throws -> LoginResult {
        LoginResult(
            session: try toAuthSession(),
            isFirstLink: isFirstLink ?? true
        )
    }
}

private struct MemberDTO: Decodable {
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
    let entitlements: EntitlementsDTO

    func toMemberProfile() throws -> MemberProfile {
        let tier = MembershipTier(rawValue: membershipTier) ?? .basic
        let status = MembershipStatus(rawValue: membershipStatus) ?? .inactive

        return MemberProfile(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            address: address,
            membershipTier: tier,
            membershipStatus: status,
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

private struct EntitlementsDTO: Decodable {
    let canViewDeals: Bool
    let canSaveDeals: Bool
    let canRedeemDeals: Bool
    let isChamberAdmin: Bool
}
