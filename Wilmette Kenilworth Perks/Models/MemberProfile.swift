import Foundation

struct MemberProfile: Codable, Identifiable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let membershipTier: MembershipTier
    let membershipStatus: MembershipStatus
    let companyId: String?
    let companyName: String?
    let memberSince: Date?
    let entitlements: MemberEntitlements

    var fullName: String { "\(firstName) \(lastName)" }

    var greetingName: String { firstName }

    var isMembershipActive: Bool {
        membershipStatus.isEntitled
    }
}

struct CompanyProfile: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let category: String?
    let websiteURL: URL?
}
