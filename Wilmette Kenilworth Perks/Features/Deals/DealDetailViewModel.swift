import Foundation
import Observation

@Observable
@MainActor
final class DealDetailViewModel {
    private(set) var deal: DealDetail?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let dealsService: any DealsServicing

    init(dealsService: any DealsServicing = AppDependencies.shared.dealsService) {
        self.dealsService = dealsService
    }

    func load(dealId: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            deal = try await dealsService.fetchDeal(id: dealId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
