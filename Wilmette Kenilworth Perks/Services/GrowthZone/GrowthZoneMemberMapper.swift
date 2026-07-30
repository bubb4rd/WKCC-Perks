import Foundation

enum GrowthZoneMemberMapper {
    static func map(_ snapshot: GrowthZoneMemberSnapshot) -> MemberProfile {
        let userInfo = snapshot.userInfo
        let aboutMe = snapshot.aboutMe
        let personSummary = snapshot.personSummary

        let firstName = firstNonEmpty(
            aboutMe.firstName,
            personSummary?.firstName,
            userInfo.givenName
        ) ?? "Member"

        let lastName = firstNonEmpty(
            aboutMe.lastName,
            personSummary?.lastName,
            userInfo.familyName
        ) ?? ""

        let email = firstNonEmpty(
            userInfo.email,
            personSummary?.email
        ) ?? ""

        let companyId = aboutMe.currentOrganizationId.map(String.init)
            ?? personSummary?.organizationId.map(String.init)

        let companyName = firstNonEmpty(
            aboutMe.currentOrganizationName,
            personSummary?.organizationName
        )

        let membershipStatus = resolveMembershipStatus(
            personSummary: personSummary,
            memberships: snapshot.memberships
        )

        let membershipTier = resolveMembershipTier(
            personSummary: personSummary,
            memberships: snapshot.memberships
        )

        let memberSince = parseDate(
            personSummary?.membershipEstablished
        ) ?? snapshot.memberships.compactMap { parseDate($0.establishedDate) }.first

        let entitlements = resolveEntitlements(
            membershipStatus: membershipStatus,
            allRoles: aboutMe.allRoles
        )

        return MemberProfile(
            id: userInfo.sub,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: personSummary?.phone,
            address: personSummary?.address,
            membershipTier: membershipTier,
            membershipStatus: membershipStatus,
            companyId: companyId,
            companyName: companyName,
            companyLogoURL: nil,
            memberSince: memberSince,
            entitlements: entitlements
        )
    }

    private static func resolveMembershipStatus(
        personSummary: GrowthZonePersonSummary?,
        memberships: [GrowthZoneMembershipRecord]
    ) -> MembershipStatus {
        let candidates = [
            personSummary?.membershipStatus,
            memberships.compactMap(\.status).first,
        ].compactMap { $0 }

        for candidate in candidates {
            if let status = mapMembershipStatus(candidate) {
                return status
            }
        }

        return .pending
    }

    private static func mapMembershipStatus(_ raw: String) -> MembershipStatus? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("active") || normalized == "1" {
            return .active
        }
        if normalized.contains("expired") || normalized.contains("lapsed") {
            return .expired
        }
        if normalized.contains("pending") {
            return .pending
        }
        if normalized.contains("inactive") || normalized.contains("dropped") {
            return .inactive
        }

        return nil
    }

    private static func resolveMembershipTier(
        personSummary: GrowthZonePersonSummary?,
        memberships: [GrowthZoneMembershipRecord]
    ) -> MembershipTier {
        let candidates = [
            personSummary?.membershipLevel,
            memberships.compactMap(\.packageName).first,
            memberships.compactMap(\.level).first,
        ].compactMap { $0 }

        for candidate in candidates {
            if let tier = mapMembershipTier(candidate) {
                return tier
            }
        }

        return .basic
    }

    private static func mapMembershipTier(_ raw: String) -> MembershipTier? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("platinum") { return .platinum }
        if normalized.contains("gold") { return .gold }
        if normalized.contains("silver") { return .silver }
        if normalized.contains("non-profit") || normalized.contains("nonprofit") { return .nonProfit }
        if normalized.contains("municipal") { return .municipality }
        if normalized.contains("basic") { return .basic }

        return nil
    }

    private static func resolveEntitlements(
        membershipStatus: MembershipStatus,
        allRoles: String?
    ) -> MemberEntitlements {
        let roles = allRoles?.lowercased() ?? ""
        let isAdmin = roles.contains("admin")
            || roles.contains("staff")
            || roles.contains("chamber")

        if isAdmin {
            return .chamberAdmin
        }

        guard membershipStatus.isEntitled else {
            return .restricted
        }

        return .fullMember
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values.compactMap { value in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }.first
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: trimmed) {
            return date
        }

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd",
            "MM/dd/yyyy",
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }
}
