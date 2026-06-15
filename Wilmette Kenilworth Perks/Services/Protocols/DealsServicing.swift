import Foundation

protocol DealsServicing {
    func fetchDeals() async throws -> [DealSummary]
    func fetchDeal(id: String) async throws -> DealDetail
}
