import Foundation

struct DealSummary: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let businessId: String
    let businessName: String
    let shortDescription: String
    let category: DealCategory
    let expirationDate: Date?
    let isFeatured: Bool
    let membersOnly: Bool
    let archivedAt: Date?

    var isArchived: Bool { archivedAt != nil }

    var isExpiringSoon: Bool {
        guard let expirationDate else { return false }
        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return daysUntilExpiry >= 0 && daysUntilExpiry <= 14
    }

    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Date()
    }

    init(
        id: String,
        title: String,
        businessId: String,
        businessName: String,
        shortDescription: String,
        category: DealCategory,
        expirationDate: Date?,
        isFeatured: Bool,
        membersOnly: Bool,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.businessId = businessId
        self.businessName = businessName
        self.shortDescription = shortDescription
        self.category = category
        self.expirationDate = expirationDate
        self.isFeatured = isFeatured
        self.membersOnly = membersOnly
        self.archivedAt = archivedAt
    }
}

struct DealDetail: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let businessId: String
    let businessName: String
    let description: String
    let terms: String?
    let redemptionInstructions: String
    let redemptionCode: String?
    let startDate: Date?
    let expirationDate: Date?
    let category: DealCategory
    let imageURL: URL?
    let membersOnly: Bool
    let isFeatured: Bool
    let archivedAt: Date?

    var isArchived: Bool { archivedAt != nil }

    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Date()
    }

    var isExpiringSoon: Bool {
        guard let expirationDate else { return false }
        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return daysUntilExpiry >= 0 && daysUntilExpiry <= 14
    }

    init(
        id: String,
        title: String,
        businessId: String,
        businessName: String,
        description: String,
        terms: String?,
        redemptionInstructions: String,
        redemptionCode: String?,
        startDate: Date?,
        expirationDate: Date?,
        category: DealCategory,
        imageURL: URL?,
        membersOnly: Bool,
        isFeatured: Bool,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.businessId = businessId
        self.businessName = businessName
        self.description = description
        self.terms = terms
        self.redemptionInstructions = redemptionInstructions
        self.redemptionCode = redemptionCode
        self.startDate = startDate
        self.expirationDate = expirationDate
        self.category = category
        self.imageURL = imageURL
        self.membersOnly = membersOnly
        self.isFeatured = isFeatured
        self.archivedAt = archivedAt
    }
}

extension DealDetail {
    func toPromotionSubmission(shortDescription: String? = nil) -> PromotionSubmission {
        var submission = PromotionSubmission()
        submission.title = title
        submission.category = category
        submission.shortDescription = shortDescription
            ?? String(description.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines)
        submission.fullDescription = description
        submission.terms = terms ?? ""
        submission.redemptionInstructions = redemptionInstructions
        submission.startDate = startDate ?? Date()
        submission.endDate = expirationDate ?? Date()

        if let redemptionCode, !redemptionCode.isEmpty {
            submission.redemptionCodeType = .promoCode
            submission.redemptionCode = redemptionCode
        } else {
            submission.redemptionCodeType = .none
            submission.redemptionCode = ""
        }

        return submission
    }
}
