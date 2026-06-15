import Foundation

final class MockAuthService: AuthServicing {
    func startLogin() async throws -> AuthSession {
        try await Task.sleep(nanoseconds: AppConfig.mockAuthDelaySeconds)
        return MockData.sampleSession
    }

    func restoreSession() async -> AuthSession? {
        KeychainStore.loadSession()
    }

    func signOut() async {
        KeychainStore.clear()
    }

    func openPasswordReset() async {
        // Mock: no-op in prototype
    }
}
