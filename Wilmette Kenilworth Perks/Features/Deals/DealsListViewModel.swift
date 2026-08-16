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
    private(set) var businessLogoURLs: [String: URL] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var selectedCategory: DealCategory?
    var selectedFilter: DealFilter = .all

    private let dealsService: any DealsServicing
    private let businessService: any BusinessServicing

    init(
        dealsService: any DealsServicing = AppDependencies.shared.dealsService,
        businessService: any BusinessServicing = AppDependencies.shared.businessService
    ) {
        self.dealsService = dealsService
        self.businessService = businessService
    }

    var filteredDeals: [DealSummary] {
        deals.filter { deal in
            let matchesCategory = selectedCategory == nil || deal.category == selectedCategory

            let matchesFilter: Bool = switch selectedFilter {
            case .all: true
            case .featured: deal.isFeatured
            case .expiringSoon: deal.isExpiringSoon
            }

            return matchesCategory && matchesFilter && !deal.isExpired
        }
    }

    func logoURL(for businessId: String) -> URL? {
        businessLogoURLs[businessId]
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            async let dealsTask = dealsService.fetchDeals()
            async let businessesTask = businessService.fetchBusinesses()
            deals = try await dealsTask
            let businesses = (try? await businessesTask) ?? []
            businessLogoURLs = Dictionary(
                uniqueKeysWithValues: businesses.compactMap { business in
                    guard let logoURL = business.logoURL else { return nil }
                    return (business.id, logoURL)
                }
            )
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
