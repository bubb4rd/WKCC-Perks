import Foundation
import Observation

@Observable
@MainActor
final class DealDetailViewModel {
    private(set) var deal: DealDetail?
    private(set) var businessLogoURL: URL?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let dealsService: any DealsServicing
    private let businessService: any BusinessServicing

    init(
        dealsService: any DealsServicing = AppDependencies.shared.dealsService,
        businessService: any BusinessServicing = AppDependencies.shared.businessService
    ) {
        self.dealsService = dealsService
        self.businessService = businessService
    }

    var heroImageURL: URL? {
        deal?.imageURL ?? businessLogoURL
    }

    func load(dealId: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        businessLogoURL = nil

        do {
            let fetched = try await dealsService.fetchDeal(id: dealId)
            deal = fetched
            if fetched.imageURL == nil {
                businessLogoURL = try? await businessService.fetchBusiness(id: fetched.businessId).logoURL
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
