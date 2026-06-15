import Foundation

enum AppFlowState: Equatable {
    case launching
    case unauthenticated
    case authenticating
    case authenticated
    case restrictedMembership
    case error(String)
}

enum DealCategory: String, CaseIterable, Codable, Identifiable {
    case dining = "Dining"
    case retail = "Retail"
    case services = "Services"
    case healthWellness = "Health & Wellness"
    case events = "Events"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .dining: "fork.knife"
        case .retail: "bag"
        case .services: "wrench.and.screwdriver"
        case .healthWellness: "heart.text.square"
        case .events: "calendar"
        }
    }
}

enum MembershipTier: String, Codable, CaseIterable, Identifiable {
    case nonProfit = "Non-Profit"
    case basic = "Basic"
    case silver = "Silver"
    case gold = "Gold"
    case platinum = "Platinum"
    case municipality = "Municipality"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .basic: 0
        case .nonProfit: 1
        case .silver: 2
        case .gold: 3
        case .platinum: 4
        case .municipality: 5
        }
    }
}

enum MembershipStatus: String, Codable {
    case active
    case inactive
    case pending
    case expired

    var displayName: String {
        switch self {
        case .active: "Active"
        case .inactive: "Inactive"
        case .pending: "Pending"
        case .expired: "Expired"
        }
    }

    var isEntitled: Bool {
        self == .active
    }
}

struct MemberEntitlements: Codable, Equatable {
    let canViewDeals: Bool
    let canSaveDeals: Bool
    let canRedeemDeals: Bool
    let isBusinessAdmin: Bool

    static let fullMember = MemberEntitlements(
        canViewDeals: true,
        canSaveDeals: true,
        canRedeemDeals: true,
        isBusinessAdmin: false
    )

    static let restricted = MemberEntitlements(
        canViewDeals: false,
        canSaveDeals: false,
        canRedeemDeals: false,
        isBusinessAdmin: false
    )
}
