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

    func fetchHotDeals() async throws -> [HotDeal] {
        try await Task.sleep(nanoseconds: 300_000_000)
        let now = Date()
        let calendar = Calendar.current
        return [
            HotDeal(
                id: "mock-hot-1",
                title: "Fall Specials",
                businessId: nil,
                businessName: "Sample Cafe",
                body: "Fall specials are here through December 1st.\n\nTry them at your local Sample Cafe!",
                startDate: nil,
                expirationDate: calendar.date(byAdding: .month, value: 2, to: now)
            ),
            HotDeal(
                id: "mock-hot-2",
                title: "35% off advertising rates",
                businessId: nil,
                businessName: "Sample Magazine",
                body: "Reach every Wilmette home with a hyper-local monthly magazine.",
                startDate: nil,
                expirationDate: calendar.date(byAdding: .month, value: 3, to: now)
            )
        ]
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
