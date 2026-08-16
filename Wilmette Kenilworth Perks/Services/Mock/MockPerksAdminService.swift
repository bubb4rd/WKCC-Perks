import Foundation

final class MockPerksAdminService: PerksAdminServicing {
    private let storeOverride: MockDealsStore?

    init(store: MockDealsStore? = nil) {
        self.storeOverride = store
    }

    @MainActor
    private func resolvedStore() -> MockDealsStore {
        storeOverride ?? .shared
    }

    func fetchAllPerks() async throws -> [DealSummary] {
        try await simulateNetworkDelay()
        return await MainActor.run {
            resolvedStore().allSummaries()
        }
    }

    func fetchPerk(id: String) async throws -> DealDetail {
        try await simulateNetworkDelay()
        return try await MainActor.run {
            guard let detail = resolvedStore().detail(id: id) else {
                throw ContentError.notFound
            }
            return detail
        }
    }

    func createPerk(
        _ submission: PromotionSubmission,
        businessId: String,
        businessName: String
    ) async throws -> DealDetail {
        try await simulateNetworkDelay()

        let dealId = "deal-admin-\(UUID().uuidString.prefix(8))"
        return await MainActor.run {
            let summary = submission.makeDealSummary(
                id: dealId,
                businessId: businessId,
                businessName: businessName
            )
            let detail = submission.makeDealDetail(
                id: dealId,
                businessId: businessId,
                businessName: businessName
            )
            resolvedStore().upsert(summary: summary, detail: detail)
            return detail
        }
    }

    func updatePerk(
        id: String,
        submission: PromotionSubmission,
        businessId: String,
        businessName: String
    ) async throws -> DealDetail {
        try await simulateNetworkDelay()

        return try await MainActor.run {
            let store = resolvedStore()
            guard store.detail(id: id) != nil else {
                throw ContentError.notFound
            }

            let existingSummary = store.summary(id: id)
            let summary = submission.makeDealSummary(
                id: id,
                businessId: businessId,
                businessName: businessName
            )
            let detail = submission.makeDealDetail(
                id: id,
                businessId: businessId,
                businessName: businessName
            )

            let updatedSummary = DealSummary(
                id: summary.id,
                title: summary.title,
                businessId: summary.businessId,
                businessName: summary.businessName,
                shortDescription: summary.shortDescription,
                category: summary.category,
                expirationDate: summary.expirationDate,
                isFeatured: existingSummary?.isFeatured ?? summary.isFeatured,
                membersOnly: summary.membersOnly,
                archivedAt: existingSummary?.archivedAt
            )

            let updatedDetail = DealDetail(
                id: detail.id,
                title: detail.title,
                businessId: detail.businessId,
                businessName: detail.businessName,
                description: detail.description,
                terms: detail.terms,
                redemptionInstructions: detail.redemptionInstructions,
                redemptionCode: detail.redemptionCode,
                startDate: detail.startDate,
                expirationDate: detail.expirationDate,
                category: detail.category,
                imageURL: detail.imageURL,
                membersOnly: detail.membersOnly,
                isFeatured: existingSummary?.isFeatured ?? detail.isFeatured,
                archivedAt: existingSummary?.archivedAt
            )

            store.upsert(summary: updatedSummary, detail: updatedDetail)
            return updatedDetail
        }
    }

    func archivePerk(id: String) async throws -> DealDetail {
        try await simulateNetworkDelay()
        return try await MainActor.run {
            try resolvedStore().archive(id: id, archivedBy: "admin-mock")
        }
    }

    func unarchivePerk(id: String) async throws -> DealDetail {
        try await simulateNetworkDelay()
        return try await MainActor.run {
            try resolvedStore().unarchive(id: id)
        }
    }

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }
}
