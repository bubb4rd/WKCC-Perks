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

    /// Shows a deal that is already in hand (hot deals aren't served by `fetchDeal`).
    func show(_ deal: DealDetail, logoURL: URL?) {
        businessLogoURL = logoURL
        self.deal = deal
    }

    func load(dealId: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        businessLogoURL = nil

        do {
            let fetched = try await dealsService.fetchDeal(id: dealId)
            let logoURL: URL?
            if fetched.imageURL == nil {
                logoURL = try? await businessService.fetchBusiness(id: fetched.businessId).logoURL
            } else {
                logoURL = nil
            }
            // Assign logo before deal so the first paint already has the fallback URL.
            businessLogoURL = logoURL
            deal = fetched
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
