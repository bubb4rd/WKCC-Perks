import Foundation

struct GrowthZoneUserInfo: Decodable {
    let sub: String
    let givenName: String?
    let familyName: String?
    let email: String?
    let memTypes: String?

    enum CodingKeys: String, CodingKey {
        case sub
        case givenName = "given_name"
        case familyName = "family_name"
        case email
        case memTypes = "MemTypes"
    }
}

struct GrowthZoneAboutMe: Decodable {
    let firstName: String?
    let lastName: String?
    let contactId: Int?
    let currentOrganizationId: Int?
    let currentOrganizationName: String?
    let allRoles: String?

    enum CodingKeys: String, CodingKey {
        case firstName = "FirstName"
        case lastName = "LastName"
        case contactId = "ContactId"
        case currentOrganizationId = "CurrentOrganizationId"
        case currentOrganizationName = "CurrentOrganizationName"
        case allRoles = "AllRoles"
    }
}

struct GrowthZonePersonSummary: Decodable {
    let contactId: Int?
    let firstName: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let address: String?
    let membershipStatus: String?
    let membershipLevel: String?
    let membershipEstablished: String?
    let organizationName: String?
    let organizationId: Int?

    enum CodingKeys: String, CodingKey {
        case contactId = "ContactId"
        case firstName = "FirstName"
        case lastName = "LastName"
        case email = "Email"
        case phone = "Phone"
        case address = "Address"
        case membershipStatus = "MembershipStatus"
        case membershipLevel = "MembershipLevel"
        case organizationName = "OrganizationName"
        case organizationId = "OrganizationId"
        case membershipEstablished = "MembershipEstablished"
    }
}

struct GrowthZoneMembershipRecord: Decodable {
    let status: String?
    let level: String?
    let packageName: String?
    let establishedDate: String?

    enum CodingKeys: String, CodingKey {
        case status = "Status"
        case level = "Level"
        case packageName = "PackageName"
        case establishedDate = "EstablishedDate"
    }
}
