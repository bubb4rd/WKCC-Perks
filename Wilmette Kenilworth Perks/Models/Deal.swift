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

    var isExpiringSoon: Bool {
        guard let expirationDate else { return false }
        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return daysUntilExpiry >= 0 && daysUntilExpiry <= 14
    }

    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Date()
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

    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Date()
    }
}
