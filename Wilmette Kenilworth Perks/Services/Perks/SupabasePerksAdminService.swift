import Foundation

final class SupabasePerksAdminService: PerksAdminServicing {
    func fetchAllPerks() async throws -> [DealSummary] {
        let rows: [PerksDealSummaryDTO] = try await PerksAPIClient.request(
            method: .get,
            path: "admin/deals",
            as: [PerksDealSummaryDTO].self
        )
        return rows.map { $0.toModel() }
    }

    func fetchPerk(id: String) async throws -> DealDetail {
        do {
            let row: PerksDealDetailDTO = try await PerksAPIClient.request(
                method: .get,
                path: "admin/deals/\(id)",
                as: PerksDealDetailDTO.self
            )
            return row.toModel()
        } catch PerksAPIClient.RequestError.notFound {
            throw ContentError.notFound
        }
    }

    func createPerk(
        _ submission: PromotionSubmission,
        businessId: String,
        businessName: String
    ) async throws -> DealDetail {
        struct Body: Encodable {
            let submission: PromotionSubmission
            let businessId: String
            let businessName: String
        }

        let row: PerksDealDetailDTO = try await PerksAPIClient.request(
            method: .post,
            path: "admin/deals",
            body: Body(
                submission: submission,
                businessId: businessId,
                businessName: businessName
            ),
            as: PerksDealDetailDTO.self
        )
        return row.toModel()
    }

    func updatePerk(
        id: String,
        submission: PromotionSubmission,
        businessId: String,
        businessName: String
    ) async throws -> DealDetail {
        struct Body: Encodable {
            let submission: PromotionSubmission
            let businessId: String
            let businessName: String
        }

        do {
            let row: PerksDealDetailDTO = try await PerksAPIClient.request(
                method: .patch,
                path: "admin/deals/\(id)",
                body: Body(
                    submission: submission,
                    businessId: businessId,
                    businessName: businessName
                ),
                as: PerksDealDetailDTO.self
            )
            return row.toModel()
        } catch PerksAPIClient.RequestError.notFound {
            throw ContentError.notFound
        }
    }

    func archivePerk(id: String) async throws -> DealDetail {
        do {
            let row: PerksDealDetailDTO = try await PerksAPIClient.request(
                method: .post,
                path: "admin/deals/\(id)/archive",
                as: PerksDealDetailDTO.self
            )
            return row.toModel()
        } catch PerksAPIClient.RequestError.notFound {
            throw ContentError.notFound
        }
    }

    func unarchivePerk(id: String) async throws -> DealDetail {
        do {
            let row: PerksDealDetailDTO = try await PerksAPIClient.request(
                method: .post,
                path: "admin/deals/\(id)/unarchive",
                as: PerksDealDetailDTO.self
            )
            return row.toModel()
        } catch PerksAPIClient.RequestError.notFound {
            throw ContentError.notFound
        }
    }
}
