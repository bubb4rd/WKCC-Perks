import Foundation

final class SupabaseDealsService: DealsServicing {
    func fetchDeals() async throws -> [DealSummary] {
        let rows: [PerksDealSummaryDTO] = try await PerksAPIClient.request(
            method: .get,
            path: "deals",
            as: [PerksDealSummaryDTO].self
        )
        return rows.map { $0.toModel() }
    }

    func fetchDeal(id: String) async throws -> DealDetail {
        do {
            let row: PerksDealDetailDTO = try await PerksAPIClient.request(
                method: .get,
                path: "deals/\(id)",
                as: PerksDealDetailDTO.self
            )
            return row.toModel()
        } catch PerksAPIClient.RequestError.notFound {
            throw ContentError.notFound
        }
    }
}
