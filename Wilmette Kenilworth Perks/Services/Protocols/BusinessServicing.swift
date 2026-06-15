import Foundation

protocol BusinessServicing {
    func fetchBusinesses() async throws -> [ChamberBusiness]
    func fetchBusiness(id: String) async throws -> ChamberBusiness
}
