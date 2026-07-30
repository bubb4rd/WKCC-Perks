import Foundation

@MainActor
final class MockDealsStore {
    static let shared = MockDealsStore()

    private var summaries: [DealSummary] = []
    private var details: [DealDetail] = []
    private var isLoaded = false

    private init() {}

    func allSummaries() -> [DealSummary] {
        ensureLoaded()
        return summaries
    }

    func activeSummaries() -> [DealSummary] {
        ensureLoaded()
        return summaries.filter { !$0.isArchived }
    }

    func allDetails() -> [DealDetail] {
        ensureLoaded()
        return details
    }

    func summary(id: String) -> DealSummary? {
        ensureLoaded()
        return summaries.first { $0.id == id }
    }

    func detail(id: String) -> DealDetail? {
        ensureLoaded()
        return details.first { $0.id == id }
    }

    func upsert(summary: DealSummary, detail: DealDetail) {
        ensureLoaded()
        guard summary.id == detail.id else { return }

        if let index = summaries.firstIndex(where: { $0.id == summary.id }) {
            summaries[index] = summary
            details[index] = detail
        } else {
            summaries.append(summary)
            details.append(detail)
        }
    }

    func publish(summary: DealSummary, detail: DealDetail) {
        upsert(summary: summary, detail: detail)
    }

    @discardableResult
    func archive(id: String, archivedBy: String) throws -> DealDetail {
        ensureLoaded()
        guard let index = details.firstIndex(where: { $0.id == id }) else {
            throw ContentError.notFound
        }
        guard details[index].archivedAt == nil else {
            throw ContentError.invalidState
        }

        let now = Date()
        let summary = summaries[index]
        let detail = details[index]

        let archivedSummary = DealSummary(
            id: summary.id,
            title: summary.title,
            businessId: summary.businessId,
            businessName: summary.businessName,
            shortDescription: summary.shortDescription,
            category: summary.category,
            expirationDate: summary.expirationDate,
            isFeatured: summary.isFeatured,
            membersOnly: summary.membersOnly,
            archivedAt: now
        )
        let archivedDetail = DealDetail(
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
            isFeatured: detail.isFeatured,
            archivedAt: now
        )
        _ = archivedBy
        upsert(summary: archivedSummary, detail: archivedDetail)
        return archivedDetail
    }

    @discardableResult
    func unarchive(id: String) throws -> DealDetail {
        ensureLoaded()
        guard let index = details.firstIndex(where: { $0.id == id }) else {
            throw ContentError.notFound
        }
        guard details[index].archivedAt != nil else {
            throw ContentError.invalidState
        }

        let summary = summaries[index]
        let detail = details[index]

        let restoredSummary = DealSummary(
            id: summary.id,
            title: summary.title,
            businessId: summary.businessId,
            businessName: summary.businessName,
            shortDescription: summary.shortDescription,
            category: summary.category,
            expirationDate: summary.expirationDate,
            isFeatured: summary.isFeatured,
            membersOnly: summary.membersOnly,
            archivedAt: nil
        )
        let restoredDetail = DealDetail(
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
            isFeatured: detail.isFeatured,
            archivedAt: nil
        )
        upsert(summary: restoredSummary, detail: restoredDetail)
        return restoredDetail
    }

    func resetToSeedData() {
        summaries = MockData.dealSummaries
        details = MockData.dealDetails
        isLoaded = true
    }

    private func ensureLoaded() {
        guard !isLoaded else { return }
        summaries = MockData.dealSummaries
        details = MockData.dealDetails
        isLoaded = true
    }
}
