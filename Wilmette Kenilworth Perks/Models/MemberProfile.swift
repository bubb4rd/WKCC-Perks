import Foundation

struct MemberProfile: Codable, Identifiable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let phone: String?
    let address: String?
    let membershipTier: MembershipTier
    let membershipStatus: MembershipStatus
    let companyId: String?
    let companyName: String?
    let companyLogoURL: URL?
    let memberSince: Date?
    let entitlements: MemberEntitlements

    var fullName: String { "\(firstName) \(lastName)" }

    var greetingName: String { firstName }

    var isMembershipActive: Bool {
        membershipStatus.isEntitled
    }

    func withCompanyLogoURL(_ url: URL?) -> MemberProfile {
        MemberProfile(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            address: address,
            membershipTier: membershipTier,
            membershipStatus: membershipStatus,
            companyId: companyId,
            companyName: companyName,
            companyLogoURL: url,
            memberSince: memberSince,
            entitlements: entitlements
        )
    }
}

struct CompanyProfile: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let category: String?
    let websiteURL: URL?
}
