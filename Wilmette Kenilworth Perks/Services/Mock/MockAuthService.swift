import Foundation

final class MockAuthService: AuthServicing {
    private var lastRequestedEmail: String?
    private let linkedEmailsKey = "mock.linkedEmails"

    func requestLoginCode(email: String) async throws {
        try await Task.sleep(nanoseconds: AppConfig.mockAuthDelaySeconds / 2)
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.contains("@") else {
            throw AuthError.underlying(NSError(
                domain: "MockAuth",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Enter a valid email address."]
            ))
        }
        // Mock mode never sends email. Testers use AppConfig.mockLoginCode.
        lastRequestedEmail = normalized
    }

    func verifyLoginCode(email: String, code: String) async throws -> LoginResult {
        try await Task.sleep(nanoseconds: AppConfig.mockAuthDelaySeconds)
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedCode == AppConfig.mockLoginCode else {
            throw AuthError.invalidCode
        }

        _ = lastRequestedEmail ?? normalized

        let member: MemberProfile
        if normalized == MockData.adminMember.email.lowercased() {
            // Admin UI testing: allow chamber staff email even if absent from the export.
            member = MockData.adminMember
        } else if let record = MockChamberMemberStore.eligibleMember(for: normalized) {
            member = MockChamberMemberMapper.map(record)
        } else {
            throw AuthError.membershipInactive
        }

        let isFirstLink = !hasLinked(email: normalized)
        markLinked(email: normalized)

        let session = AuthSession(
            accessToken: "mock-access-\(member.id)",
            refreshToken: "mock-refresh-\(member.id)",
            expiresAt: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            member: member
        )

        return LoginResult(session: session, isFirstLink: isFirstLink)
    }

    func restoreSession() async -> AuthSession? {
        KeychainStore.loadSession()
    }

    func refreshSession(_ session: AuthSession) async throws -> AuthSession {
        session
    }

    func signOut() async {
        KeychainStore.clear()
    }

    func uploadCompanyLogo(imageData: Data, contentType: String) async throws -> MemberProfile {
        try await Task.sleep(nanoseconds: 400_000_000)

        guard var stored = KeychainStore.loadSession() else {
            throw AuthError.sessionExpired
        }

        let companyId = stored.member.companyId ?? stored.member.id
        let logoURL = try MockBusinessLogoStore.setLogo(companyId: companyId, imageData: imageData)
        let updatedMember = stored.member.withCompanyLogoURL(logoURL)
        stored = AuthSession(
            accessToken: stored.accessToken,
            refreshToken: stored.refreshToken,
            expiresAt: stored.expiresAt,
            member: updatedMember
        )
        try KeychainStore.save(stored)
        return updatedMember
    }

    private func hasLinked(email: String) -> Bool {
        let linked = UserDefaults.standard.stringArray(forKey: linkedEmailsKey) ?? []
        return linked.contains(email)
    }

    private func markLinked(email: String) {
        var linked = UserDefaults.standard.stringArray(forKey: linkedEmailsKey) ?? []
        if !linked.contains(email) {
            linked.append(email)
            UserDefaults.standard.set(linked, forKey: linkedEmailsKey)
        }
    }
}
