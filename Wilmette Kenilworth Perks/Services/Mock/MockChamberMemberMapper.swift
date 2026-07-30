import Foundation

struct MockChamberMemberRecord: Codable, Equatable {
    let cmId: Int
    let name: String
    let displayName: String
    let email: String?
    let status: String
    let displayFlags: String
    let membershipEstablished: String?

    enum CodingKeys: String, CodingKey {
        case cmId = "cm_id"
        case name
        case displayName = "display_name"
        case email
        case status
        case displayFlags = "display_flags"
        case membershipEstablished = "membership_established"
    }

    var isEligible: Bool {
        guard let email, !email.isEmpty else { return false }
        guard status == "2" else { return false }
        guard !displayFlags.contains("DisableLogin") else { return false }
        return true
    }
}

enum MockChamberMemberStore {
    private static let activeStatus = "2"

    static let members: [MockChamberMemberRecord] = {
        guard let url = Bundle.main.url(forResource: "MockChamberMembers", withExtension: "json") else {
            assertionFailure("MockChamberMembers.json is missing from the app bundle.")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([MockChamberMemberRecord].self, from: data)
        } catch {
            assertionFailure("Failed to decode MockChamberMembers.json: \(error)")
            return []
        }
    }()

    static func eligibleMember(for email: String) -> MockChamberMemberRecord? {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return members
            .filter { $0.email == normalized && $0.isEligible }
            .sorted { $0.cmId < $1.cmId }
            .first
    }
}

enum MockChamberMemberMapper {
    static func map(
        _ record: MockChamberMemberRecord,
        adminEmail: String = MockData.adminMember.email
    ) -> MemberProfile {
        let names = deriveNames(from: record)
        let isActive = record.status == "2"
        let email = record.email ?? ""
        let isAdmin = email.caseInsensitiveCompare(adminEmail) == .orderedSame

        let companyId = String(record.cmId)
        return MemberProfile(
            id: companyId,
            firstName: names.firstName,
            lastName: names.lastName,
            email: email,
            phone: nil,
            address: nil,
            membershipTier: .basic,
            membershipStatus: isActive ? .active : .inactive,
            companyId: companyId,
            companyName: record.name,
            companyLogoURL: MockBusinessLogoStore.logoURL(for: companyId),
            memberSince: parseDate(record.membershipEstablished),
            entitlements: isActive
                ? MemberEntitlements(
                    canViewDeals: true,
                    canSaveDeals: true,
                    canRedeemDeals: true,
                    isChamberAdmin: isAdmin
                )
                : .restricted
        )
    }

    private static func deriveNames(from record: MockChamberMemberRecord) -> (firstName: String, lastName: String) {
        let display = record.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if display.contains(" ") {
            let parts = display.split(whereSeparator: \.isWhitespace).map(String.init)
            return (parts[0], parts.dropFirst().joined(separator: " "))
        }

        if let email = record.email, email.contains("@") {
            let local = email.split(separator: "@", maxSplits: 1).first.map(String.init) ?? "Member"
            let cleaned = local
                .replacingOccurrences(of: "[._-]+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = cleaned.split(whereSeparator: \.isWhitespace).map(String.init)
            if parts.count >= 2 {
                return (capitalize(parts[0]), capitalize(parts.dropFirst().joined(separator: " ")))
            }
            return (capitalize(parts.first ?? "Member"), display.isEmpty ? "Member" : display)
        }

        return (display.isEmpty ? "Member" : display, "")
    }

    private static func capitalize(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        if let date = formatter.date(from: value) {
            return date
        }
        // ChamberMaster export uses "2023-05-09T00:00:00" without timezone.
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return fallback.date(from: value)
    }
}
