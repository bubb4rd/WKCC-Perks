import Foundation

struct ChamberBusiness: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let category: DealCategory
    let shortDescription: String
    let fullDescription: String?
    let logoURL: URL?
    let websiteURL: URL?
    let phone: String?
    let address: String?
    /// When false, address is hidden from the public directory (owner still receives it on own fetch).
    let addressPublic: Bool
    let email: String?
    let latitude: Double?
    let longitude: Double?
    let memberSince: Date?
    let isChamberPartner: Bool
    let activeDeals: [DealSummary]
    let redemptionNotes: String?

    var activeDealCount: Int {
        activeDeals.filter { !$0.isExpired }.count
    }

    /// True when membership date is usable for display (excludes ChamberMaster sentinel years).
    var displayableMemberSince: Date? {
        guard let memberSince else { return nil }
        let year = Calendar.current.component(.year, from: memberSince)
        guard year >= 1950 else { return nil }
        return memberSince
    }

    var hasMapCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    var aboutText: String? {
        let full = fullDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !full.isEmpty { return full }
        let short = shortDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return short.isEmpty ? nil : short
    }

    var isProfileIncomplete: Bool {
        let hasLogo = logoURL != nil
        let hasCategory = category != .other
        let hasAbout = !(shortDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let hasWebsite = websiteURL != nil
        let hasPhone = !(phone?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasAddress = !(address?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return !hasLogo || !hasCategory || !hasAbout || !hasWebsite || !hasPhone || !hasAddress
    }

    init(
        id: String,
        name: String,
        category: DealCategory,
        shortDescription: String,
        fullDescription: String?,
        logoURL: URL?,
        websiteURL: URL?,
        phone: String?,
        address: String?,
        addressPublic: Bool = true,
        email: String?,
        latitude: Double?,
        longitude: Double?,
        memberSince: Date?,
        isChamberPartner: Bool,
        activeDeals: [DealSummary],
        redemptionNotes: String?
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.shortDescription = shortDescription
        self.fullDescription = fullDescription
        self.logoURL = logoURL
        self.websiteURL = websiteURL
        self.phone = phone
        self.address = address
        self.addressPublic = addressPublic
        self.email = email
        self.latitude = latitude
        self.longitude = longitude
        self.memberSince = memberSince
        self.isChamberPartner = isChamberPartner
        self.activeDeals = activeDeals
        self.redemptionNotes = redemptionNotes
    }

    func withLogoURL(_ logoURL: URL?) -> ChamberBusiness {
        ChamberBusiness(
            id: id,
            name: name,
            category: category,
            shortDescription: shortDescription,
            fullDescription: fullDescription,
            logoURL: logoURL,
            websiteURL: websiteURL,
            phone: phone,
            address: address,
            addressPublic: addressPublic,
            email: email,
            latitude: latitude,
            longitude: longitude,
            memberSince: memberSince,
            isChamberPartner: isChamberPartner,
            activeDeals: activeDeals,
            redemptionNotes: redemptionNotes
        )
    }

    func applyingProfile(_ update: CompanyProfileUpdate) -> ChamberBusiness {
        ChamberBusiness(
            id: id,
            name: name,
            category: update.category,
            shortDescription: update.shortDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            fullDescription: fullDescription,
            logoURL: logoURL,
            websiteURL: Self.url(from: update.websiteURLString),
            phone: Self.optionalText(update.phone),
            address: Self.optionalText(update.address),
            addressPublic: update.addressPublic,
            email: email,
            latitude: latitude,
            longitude: longitude,
            memberSince: memberSince,
            isChamberPartner: isChamberPartner,
            activeDeals: activeDeals,
            redemptionNotes: redemptionNotes
        )
    }

    private static func optionalText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func url(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }
}

struct CompanyProfileUpdate: Equatable {
    var category: DealCategory
    var shortDescription: String
    var websiteURLString: String
    var phone: String
    var address: String
    var addressPublic: Bool

    init(
        category: DealCategory = .other,
        shortDescription: String = "",
        websiteURLString: String = "",
        phone: String = "",
        address: String = "",
        addressPublic: Bool = true
    ) {
        self.category = category
        self.shortDescription = shortDescription
        self.websiteURLString = websiteURLString
        self.phone = phone
        self.address = address
        self.addressPublic = addressPublic
    }

    init(business: ChamberBusiness) {
        category = business.category
        shortDescription = business.shortDescription
        websiteURLString = business.websiteURL?.absoluteString ?? ""
        phone = business.phone ?? ""
        address = business.address ?? ""
        addressPublic = business.addressPublic
    }
}
