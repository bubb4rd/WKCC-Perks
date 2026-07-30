import Foundation
import Testing
@testable import Wilmette_Kenilworth_Perks

struct GrowthZoneMemberMapperTests {
    @Test func mapsActiveMemberWithOrganization() {
        let snapshot = GrowthZoneMemberSnapshot(
            userInfo: GrowthZoneUserInfo(
                sub: "12345",
                givenName: "Jane",
                familyName: "Doe",
                email: "jane@example.com",
                memTypes: nil
            ),
            aboutMe: GrowthZoneAboutMe(
                firstName: "Jane",
                lastName: "Doe",
                contactId: 99,
                currentOrganizationId: 42,
                currentOrganizationName: "North Shore Financial Group",
                allRoles: "Member"
            ),
            personSummary: GrowthZonePersonSummary(
                contactId: 99,
                firstName: "Jane",
                lastName: "Doe",
                email: "jane@example.com",
                phone: "847-555-0100",
                address: "123 Main St",
                membershipStatus: "Active",
                membershipLevel: "Gold",
                membershipEstablished: "2019-03-15",
                organizationName: "North Shore Financial Group",
                organizationId: 42
            ),
            memberships: []
        )

        let member = GrowthZoneMemberMapper.map(snapshot)

        #expect(member.id == "12345")
        #expect(member.firstName == "Jane")
        #expect(member.lastName == "Doe")
        #expect(member.email == "jane@example.com")
        #expect(member.phone == "847-555-0100")
        #expect(member.companyId == "42")
        #expect(member.companyName == "North Shore Financial Group")
        #expect(member.membershipStatus == .active)
        #expect(member.membershipTier == .gold)
        #expect(member.entitlements.canViewDeals)
    }

    @Test func mapsInactiveMemberToRestrictedEntitlements() {
        let snapshot = GrowthZoneMemberSnapshot(
            userInfo: GrowthZoneUserInfo(
                sub: "67890",
                givenName: "James",
                familyName: "Chen",
                email: "james@example.com",
                memTypes: nil
            ),
            aboutMe: GrowthZoneAboutMe(
                firstName: nil,
                lastName: nil,
                contactId: 100,
                currentOrganizationId: nil,
                currentOrganizationName: nil,
                allRoles: "Member"
            ),
            personSummary: GrowthZonePersonSummary(
                contactId: 100,
                firstName: nil,
                lastName: nil,
                email: nil,
                phone: nil,
                address: nil,
                membershipStatus: "Expired",
                membershipLevel: "Basic",
                membershipEstablished: nil,
                organizationName: nil,
                organizationId: nil
            ),
            memberships: []
        )

        let member = GrowthZoneMemberMapper.map(snapshot)

        #expect(member.membershipStatus == .expired)
        #expect(member.entitlements == .restricted)
    }

    @Test func mapsChamberAdminRole() {
        let snapshot = GrowthZoneMemberSnapshot(
            userInfo: GrowthZoneUserInfo(
                sub: "admin-1",
                givenName: "Patricia",
                familyName: "Walsh",
                email: "admin@wilmettekenilworth.com",
                memTypes: nil
            ),
            aboutMe: GrowthZoneAboutMe(
                firstName: "Patricia",
                lastName: "Walsh",
                contactId: 1,
                currentOrganizationId: nil,
                currentOrganizationName: nil,
                allRoles: "Chamber Admin"
            ),
            personSummary: nil,
            memberships: [
                GrowthZoneMembershipRecord(
                    status: "Active",
                    level: "Platinum",
                    packageName: "Platinum",
                    establishedDate: nil
                ),
            ]
        )

        let member = GrowthZoneMemberMapper.map(snapshot)

        #expect(member.entitlements.isChamberAdmin)
        #expect(member.membershipTier == .platinum)
    }
}

struct GrowthZonePKCETests {
    @Test func challengeIsDerivedFromVerifier() {
        let verifier = GrowthZonePKCE.generateVerifier()
        let challenge = GrowthZonePKCE.challenge(for: verifier)

        #expect(!verifier.isEmpty)
        #expect(!challenge.isEmpty)
        #expect(challenge != verifier)
    }
}
