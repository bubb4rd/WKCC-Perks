import Foundation
import Observation

enum DealFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case featured = "Featured"
    case expiringSoon = "Expiring Soon"

    var id: String { rawValue }
}

@Observable
@MainActor
final class DealsListViewModel {
    private(set) var deals: [DealSummary] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var searchText = ""
    var selectedCategory: DealCategory?
    var selectedFilter: DealFilter = .all

    private let dealsService: any DealsServicing

    init(dealsService: any DealsServicing = AppDependencies.shared.dealsService) {
        self.dealsService = dealsService
    }

    var filteredDeals: [DealSummary] {
        deals.filter { deal in
            let matchesSearch = searchText.isEmpty
                || deal.title.localizedCaseInsensitiveContains(searchText)
                || deal.businessName.localizedCaseInsensitiveContains(searchText)

            let matchesCategory = selectedCategory == nil || deal.category == selectedCategory

            let matchesFilter: Bool = switch selectedFilter {
            case .all: true
            case .featured: deal.isFeatured
            case .expiringSoon: deal.isExpiringSoon
            }

            return matchesSearch && matchesCategory && matchesFilter && !deal.isExpired
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            deals = try await dealsService.fetchDeals()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func dismissError() {
        errorMessage = nil
    }

    func applyInitialCategory(_ category: DealCategory?) {
        selectedCategory = category
    }

    func applyInitialFilter(_ filter: DealFilter) {
        selectedFilter = filter
    }
}
