import Foundation

final class MockBusinessService: BusinessServicing {
    func fetchBusinesses() async throws -> [ChamberBusiness] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return catalog.map(applyStoredOverrides)
    }

    func fetchBusiness(id: String) async throws -> ChamberBusiness {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard let business = catalog.first(where: { $0.id == id }) else {
            throw ContentError.notFound
        }
        return applyStoredOverrides(business)
    }

    func updateCompanyProfile(_ update: CompanyProfileUpdate) async throws -> ChamberBusiness {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard let stored = KeychainStore.loadSession() else {
            throw AuthError.sessionExpired
        }
        let companyId = stored.member.companyId ?? stored.member.id
        MockBusinessProfileStore.setProfile(update, for: companyId)
        return try await fetchBusiness(id: companyId)
    }

    /// Active chamber members from the export (same source as live `chamber_members`).
    private var catalog: [ChamberBusiness] {
        let fromMembers = MockChamberMemberStore.members
            .filter { $0.status == "2" }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            .map(Self.mapBusiness)

        // Fallback if the JSON bundle is missing in a broken build.
        return fromMembers.isEmpty ? MockData.businesses : fromMembers
    }

    private static func mapBusiness(_ record: MockChamberMemberRecord) -> ChamberBusiness {
        let id = String(record.cmId)
        let activeDeals = MockData.dealSummaries.filter {
            $0.businessId == id && !$0.isExpired && !$0.isArchived
        }
        let name = record.displayName.isEmpty ? record.name : record.displayName

        return ChamberBusiness(
            id: id,
            name: name,
            category: .other,
            shortDescription: "",
            fullDescription: nil,
            logoURL: nil,
            websiteURL: nil,
            phone: nil,
            address: nil,
            addressPublic: true,
            email: record.email,
            latitude: nil,
            longitude: nil,
            memberSince: parseMemberSince(record.membershipEstablished),
            isChamberPartner: true,
            activeDeals: activeDeals,
            redemptionNotes: nil
        )
    }

    private static func parseMemberSince(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: value) { return date }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return fallback.date(from: value)
    }

    private func applyStoredOverrides(_ business: ChamberBusiness) -> ChamberBusiness {
        var result = business
        if let profile = MockBusinessProfileStore.profile(for: business.id) {
            result = result.applyingProfile(profile)
        }
        let logo = MockBusinessLogoStore.logoURL(for: business.id) ?? result.logoURL
        return result.withLogoURL(logo)
    }
}
