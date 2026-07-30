import Foundation

protocol PerksAdminServicing {
    func fetchAllPerks() async throws -> [DealSummary]
    func fetchPerk(id: String) async throws -> DealDetail
    func createPerk(
        _ submission: PromotionSubmission,
        businessId: String,
        businessName: String
    ) async throws -> DealDetail
    func updatePerk(
        id: String,
        submission: PromotionSubmission,
        businessId: String,
        businessName: String
    ) async throws -> DealDetail
    func archivePerk(id: String) async throws -> DealDetail
    func unarchivePerk(id: String) async throws -> DealDetail
}
