import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var deals: [DealSummary] = []
    private(set) var businesses: [ChamberBusiness] = []
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

    var activeDeals: [DealSummary] {
        deals.filter { !$0.isExpired }
    }

    var featuredDeals: [DealSummary] {
        activeDeals.filter(\.isFeatured)
    }

    var spotlightDeal: DealSummary? {
        featuredDeals.first ?? activeDeals.first
    }

    var expiringSoonDeals: [DealSummary] {
        activeDeals.filter(\.isExpiringSoon)
    }

    var previewBusinesses: [ChamberBusiness] {
        Array(businesses.prefix(6))
    }

    var activeDealCount: Int { activeDeals.count }
    var expiringDealCount: Int { expiringSoonDeals.count }
    var businessCount: Int { businesses.count }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let dealsTask = dealsService.fetchDeals()
            async let businessesTask = businessService.fetchBusinesses()
            deals = try await dealsTask
            businesses = try await businessesTask
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func dismissError() {
        errorMessage = nil
    }
}
