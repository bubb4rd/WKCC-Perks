import Foundation

enum AppFlowState: Equatable {
    case launching
    case unauthenticated
    case authenticating
    /// First-time link: session verified, waiting for user to confirm chamber data.
    case confirmingLink
    case authenticated
    case restrictedMembership
    case error(String)
}

enum DealCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case shoppingSpecialtyRetail = "Shopping and Specialty Retail"
    case healthCare = "Health Care"
    case homeGarden = "Home and Garden"
    case restaurantsFoodBeverages = "Restaurants, Food and Beverages"
    case governmentEducationIndividuals = "Government, Education and Individuals"
    case personalServicesCare = "Personal Services and Care"
    case businessProfessionalServices = "Business and Professional Services"
    case financeInsurance = "Finance and Insurance"
    case advertisingMedia = "Advertising and Media"
    case other = "Other"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .shoppingSpecialtyRetail: "bag"
        case .healthCare: "cross.case"
        case .homeGarden: "leaf"
        case .restaurantsFoodBeverages: "fork.knife"
        case .governmentEducationIndividuals: "building.columns"
        case .personalServicesCare: "person.crop.circle"
        case .businessProfessionalServices: "briefcase"
        case .financeInsurance: "banknote"
        case .advertisingMedia: "megaphone"
        case .other: "square.grid.2x2"
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
    case chamber = "Chamber of Commerce"

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
        case .chamber: 6
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
    let isChamberAdmin: Bool

    static let fullMember = MemberEntitlements(
        canViewDeals: true,
        canSaveDeals: true,
        canRedeemDeals: true,
        isChamberAdmin: false
    )

    static let chamberAdmin = MemberEntitlements(
        canViewDeals: true,
        canSaveDeals: true,
        canRedeemDeals: true,
        isChamberAdmin: true
    )

    static let restricted = MemberEntitlements(
        canViewDeals: false,
        canSaveDeals: false,
        canRedeemDeals: false,
        isChamberAdmin: false
    )
}

extension Notification.Name {
    static let businessLogoDidChange = Notification.Name("wkcc.businessLogoDidChange")
    static let memberSessionDidRefresh = Notification.Name("wkcc.memberSessionDidRefresh")
    static let memberSessionDidExpire = Notification.Name("wkcc.memberSessionDidExpire")
}
