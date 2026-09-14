import Foundation

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let member: MemberProfile

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }

    /// True when the access token is within `seconds` of expiry (or already expired).
    func isExpiring(within seconds: TimeInterval) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.addingTimeInterval(-seconds) <= Date()
    }
}

struct LoginResult: Equatable {
    let session: AuthSession
    /// True when this email has never completed a WKCC Perks link before.
    let isFirstLink: Bool
}

enum AuthError: LocalizedError {
    case cancelled
    case invalidCode
    case invalidCredentials
    case codeExpired
    case rateLimited
    case sessionExpired
    case membershipInactive
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Sign in was cancelled."
        case .invalidCode:
            "That code is incorrect. Please try again."
        case .invalidCredentials:
            "That email or password is incorrect."
        case .codeExpired:
            "That code has expired. Request a new one."
        case .rateLimited:
            "Too many attempts. Please wait and try again."
        case .sessionExpired:
            "Your session has expired. Please sign in again."
        case .membershipInactive:
            "Your membership is not currently active."
        case .underlying(let error):
            error.localizedDescription
        }
    }
}

protocol AuthServicing {
    func requestLoginCode(email: String) async throws
    func verifyLoginCode(email: String, code: String) async throws -> LoginResult
    func signInWithPassword(email: String, password: String) async throws -> LoginResult
    /// Creates or replaces the signed-in member's password sign-in credential.
    func setPassword(_ password: String) async throws
    func restoreSession() async -> AuthSession?
    func refreshSession(_ session: AuthSession) async throws -> AuthSession
    func signOut() async
    /// Uploads a business logo for the signed-in member's company and returns the updated profile.
    func uploadCompanyLogo(imageData: Data, contentType: String) async throws -> MemberProfile
}
