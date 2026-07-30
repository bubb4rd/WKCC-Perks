import Foundation

struct GrowthZoneMemberSnapshot {
    let userInfo: GrowthZoneUserInfo
    let aboutMe: GrowthZoneAboutMe
    let personSummary: GrowthZonePersonSummary?
    let memberships: [GrowthZoneMembershipRecord]
}

struct GrowthZoneMemberAPIClient {
    private let host: URL
    private let session: URLSession

    init(
        host: URL = AppConfig.growthZoneHostURL,
        session: URLSession = .shared
    ) {
        self.host = host
        self.session = session
    }

    func fetchMemberSnapshot(accessToken: String) async throws -> GrowthZoneMemberSnapshot {
        async let userInfo = fetchUserInfo(accessToken: accessToken)
        async let aboutMe = fetchAboutMe(accessToken: accessToken)

        let resolvedAboutMe = try await aboutMe
        let resolvedUserInfo = try await userInfo

        var personSummary: GrowthZonePersonSummary?
        var memberships: [GrowthZoneMembershipRecord] = []
        if let contactId = resolvedAboutMe.contactId.map(String.init) {
            personSummary = try await fetchPersonSummary(
                contactId: contactId,
                accessToken: accessToken
            )
            memberships = try await fetchMemberships(
                contactId: contactId,
                accessToken: accessToken
            )
        }

        return GrowthZoneMemberSnapshot(
            userInfo: resolvedUserInfo,
            aboutMe: resolvedAboutMe,
            personSummary: personSummary,
            memberships: memberships
        )
    }

    private func fetchUserInfo(accessToken: String) async throws -> GrowthZoneUserInfo {
        try await get(path: "/oauth/userinfo", accessToken: accessToken)
    }

    private func fetchAboutMe(accessToken: String) async throws -> GrowthZoneAboutMe {
        try await get(path: "/api/login/aboutme", accessToken: accessToken)
    }

    private func fetchPersonSummary(
        contactId: String,
        accessToken: String
    ) async throws -> GrowthZonePersonSummary? {
        do {
            return try await get(
                path: "/api/contacts/personsummary/\(contactId)",
                accessToken: accessToken
            )
        } catch {
            return nil
        }
    }

    private func fetchMemberships(
        contactId: String,
        accessToken: String
    ) async throws -> [GrowthZoneMembershipRecord] {
        do {
            return try await get(
                path: "/api/contacts/org/\(contactId)/memberships",
                accessToken: accessToken
            )
        } catch {
            return []
        }
    }

    private func get<T: Decodable>(path: String, accessToken: String) async throws -> T {
        let url = host.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GrowthZoneServiceError.memberFetchFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GrowthZoneServiceError.memberFetchFailed
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GrowthZoneServiceError.invalidResponse
        }
    }
}
