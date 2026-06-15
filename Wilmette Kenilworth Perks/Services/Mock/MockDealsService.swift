import Foundation

final class MockDealsService: DealsServicing {
    func fetchDeals() async throws -> [DealSummary] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return MockData.dealSummaries
    }

    func fetchDeal(id: String) async throws -> DealDetail {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard let deal = MockData.dealDetails.first(where: { $0.id == id }) else {
            throw ContentError.notFound
        }
        return deal
    }
}

enum ContentError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: "Content not found."
        }
    }
}
