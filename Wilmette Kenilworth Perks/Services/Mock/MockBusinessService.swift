import Foundation

final class MockBusinessService: BusinessServicing {
    func fetchBusinesses() async throws -> [ChamberBusiness] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return MockData.businesses
    }

    func fetchBusiness(id: String) async throws -> ChamberBusiness {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard let business = MockData.businesses.first(where: { $0.id == id }) else {
            throw ContentError.notFound
        }
        return business
    }
}
