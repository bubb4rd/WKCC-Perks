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
}

enum AuthError: LocalizedError {
    case cancelled
    case invalidCallback
    case sessionExpired
    case membershipInactive
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Sign in was cancelled."
        case .invalidCallback:
            "We couldn't complete sign in. Please try again."
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
    func startLogin() async throws -> AuthSession
    func restoreSession() async -> AuthSession?
    func signOut() async
    func openPasswordReset() async
}
