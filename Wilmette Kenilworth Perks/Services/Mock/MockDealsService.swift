import Foundation

final class MockDealsService: DealsServicing {
    private let store: MockDealsStore

    init(store: MockDealsStore = .shared) {
        self.store = store
    }

    func fetchDeals() async throws -> [DealSummary] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return await MainActor.run {
            store.activeSummaries()
        }
    }

    func fetchDeal(id: String) async throws -> DealDetail {
        try await Task.sleep(nanoseconds: 300_000_000)
        return try await MainActor.run {
            guard let deal = store.detail(id: id), !deal.isArchived else {
                throw ContentError.notFound
            }
            return deal
        }
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
