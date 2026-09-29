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

/// Chambermate's business category labels verbatim, plus "Other" as the
/// fallback. Must stay in sync with supabase/functions/_shared/categories.ts.
enum DealCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case advertisingMedia = "Advertising & Media"
    case artsCultureEntertainment = "Arts, Culture & Entertainment"
    case automotiveMarine = "Automotive & Marine"
    case businessProfessionalServices = "Business & Professional Services"
    case computersTelecommunications = "Computers & Telecommunications"
    case constructionEquipmentContractors = "Construction Equipment & Contractors"
    case familyCommunityCivicOrganizations = "Family, Community & Civic Organizations"
    case financeInsurance = "Finance & Insurance"
    case governmentEducationIndividuals = "Government, Education & Individuals"
    case healthCare = "Health Care"
    case healthCareWellness = "Health Care & Wellness"
    case homeGarden = "Home & Garden"
    case industrialSuppliesServices = "Industrial Supplies & Services"
    case legal = "Legal"
    case lodgingTravel = "Lodging & Travel"
    case personalServicesCare = "Personal Services & Care"
    case petsVeterinary = "Pets & Veterinary"
    case realEstateMovingStorage = "Real Estate, Moving & Storage"
    case religiousOrganizations = "Religious Organizations"
    case restaurantsFoodBeverages = "Restaurants, Food & Beverages"
    case shoppingSpecialtyRetail = "Shopping & Specialty Retail"
    case sportsRecreation = "Sports & Recreation"
    case transportation = "Transportation"
    case other = "Other"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .advertisingMedia: "megaphone"
        case .artsCultureEntertainment: "theatermasks"
        case .automotiveMarine: "car"
        case .businessProfessionalServices: "briefcase"
        case .computersTelecommunications: "desktopcomputer"
        case .constructionEquipmentContractors: "hammer"
        case .familyCommunityCivicOrganizations: "person.3"
        case .financeInsurance: "banknote"
        case .governmentEducationIndividuals: "building.columns"
        case .healthCare: "cross.case"
        case .healthCareWellness: "heart"
        case .homeGarden: "leaf"
        case .industrialSuppliesServices: "gearshape.2"
        case .legal: "scale.3d"
        case .lodgingTravel: "bed.double"
        case .personalServicesCare: "person.crop.circle"
        case .petsVeterinary: "pawprint"
        case .realEstateMovingStorage: "house"
        case .religiousOrganizations: "building.2"
        case .restaurantsFoodBeverages: "fork.knife"
        case .shoppingSpecialtyRetail: "bag"
        case .sportsRecreation: "sportscourt"
        case .transportation: "bus"
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
