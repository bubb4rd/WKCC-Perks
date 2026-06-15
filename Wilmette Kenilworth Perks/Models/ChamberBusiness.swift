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
    let isChamberPartner: Bool
    let activeDeals: [DealSummary]
    let redemptionNotes: String?

    var activeDealCount: Int {
        activeDeals.filter { !$0.isExpired }.count
    }
}
