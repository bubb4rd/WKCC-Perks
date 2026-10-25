import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var deals: [DealSummary] = []
    private(set) var businesses: [ChamberBusiness] = []
    /// Live posts from the Chambermate Hot Deals board; when present they take the spotlight.
    private(set) var hotDeals: [HotDeal] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var searchText = ""

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

    /// The perk spotlight. Hot deals take the spotlight slot while any are live, so this is nil then
    /// and every perk falls into the list below.
    var spotlightDeal: DealSummary? {
        guard hotDeals.isEmpty else { return nil }
        return featuredDeals.first ?? activeDeals.first
    }

    var spotlightImageURL: URL? {
        guard let deal = spotlightDeal else { return nil }
        return logoURL(forBusinessId: deal.businessId)
    }

    var isFiltering: Bool {
        !trimmedSearchText.isEmpty
    }

    /// Perks listed under the spotlight. While browsing, the spotlight perk isn't repeated;
    /// while searching, the spotlight is hidden and every match is listed.
    var listedDeals: [DealSummary] {
        guard isFiltering else {
            return activeDeals.filter { $0.id != spotlightDeal?.id }
        }

        let query = trimmedSearchText
        return activeDeals.filter { deal in
            deal.title.localizedCaseInsensitiveContains(query)
                || deal.businessName.localizedCaseInsensitiveContains(query)
                || deal.shortDescription.localizedCaseInsensitiveContains(query)
        }
    }

    /// The spotlight is the only perk, so the list under it would be empty.
    var showsOnlySpotlight: Bool {
        !isFiltering && spotlightDeal != nil && listedDeals.isEmpty
    }

    var previewBusinesses: [ChamberBusiness] {
        Array(businesses.prefix(6))
    }

    func logoURL(forBusinessId id: String) -> URL? {
        businesses.first(where: { $0.id == id })?.logoURL
    }

    func logoURL(for hotDeal: HotDeal) -> URL? {
        hotDeal.businessId.flatMap { logoURL(forBusinessId: $0) }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let dealsTask = dealsService.fetchDeals()
            async let businessesTask = businessService.fetchBusinesses()
            // Supplementary: a hot deals failure (e.g. feed not deployed yet) must not blank Home.
            async let hotDealsTask = try? dealsService.fetchHotDeals()
            deals = try await dealsTask
            hotDeals = (await hotDealsTask ?? []).filter { !$0.isExpired }
            // Supplementary too: a directory failure costs logos, not the perks and hot deals.
            if let fetched = try? await businessesTask {
                businesses = fetched
            }
        } catch let error where error.isCancellation {
            // Cancelled by SwiftUI (e.g. mid-refresh); keep current content, not a failure.
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func dismissError() {
        errorMessage = nil
    }
}
