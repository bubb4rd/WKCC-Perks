import Foundation

final class MockDealsService: DealsServicing {
    private let storeOverride: MockDealsStore?

    init(store: MockDealsStore? = nil) {
        self.storeOverride = store
    }

    func fetchDeals() async throws -> [DealSummary] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return await MainActor.run {
            resolvedStore().activeSummaries()
        }
    }

    func fetchDeal(id: String) async throws -> DealDetail {
        try await Task.sleep(nanoseconds: 300_000_000)
        return try await MainActor.run {
            guard let deal = resolvedStore().detail(id: id), !deal.isArchived else {
                throw ContentError.notFound
            }
            return deal
        }
    }

    @MainActor
    private func resolvedStore() -> MockDealsStore {
        storeOverride ?? .shared
    }
}

enum ContentError: LocalizedError {
    case notFound
    case invalidState

    var errorDescription: String? {
        switch self {
        case .notFound: "Content not found."
        case .invalidState: "This item can no longer be updated."
        }
    }
}
