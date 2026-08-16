import Foundation
import Observation

@Observable
@MainActor
final class DealsSearchViewModel {
    private(set) var deals: [DealSummary] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var recentSearches: [String] = []

    var searchText = ""
    var selectedCategory: DealCategory?
    var selectedFilter: DealFilter = .all

    private let dealsService: any DealsServicing
    private let businessService: any BusinessServicing
    private let recentSearchesKey = "deals.recentSearches"
    private let maxRecentSearches = 8

    private(set) var businessLogoURLs: [String: URL] = [:]

    init(
        dealsService: any DealsServicing = AppDependencies.shared.dealsService,
        businessService: any BusinessServicing = AppDependencies.shared.businessService
    ) {
        self.dealsService = dealsService
        self.businessService = businessService
        recentSearches = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasQuery: Bool {
        !trimmedQuery.isEmpty
    }

    var hasActiveFilters: Bool {
        selectedFilter != .all || selectedCategory != nil
    }

    var filteredDeals: [DealSummary] {
        deals.filter { deal in
            let matchesSearch = !hasQuery
                || deal.title.localizedCaseInsensitiveContains(trimmedQuery)
                || deal.businessName.localizedCaseInsensitiveContains(trimmedQuery)

            let matchesCategory = selectedCategory == nil || deal.category == selectedCategory

            let matchesFilter: Bool = switch selectedFilter {
            case .all: true
            case .featured: deal.isFeatured
            case .expiringSoon: deal.isExpiringSoon
            }

            return matchesSearch && matchesCategory && matchesFilter && !deal.isExpired
        }
    }

    /// Title/business suggestions while typing, before committing to a full results browse feel.
    var suggestions: [String] {
        guard hasQuery else { return [] }

        var seen = Set<String>()
        var results: [String] = []

        for deal in deals where !deal.isExpired {
            let candidates = [deal.title, deal.businessName]
            for candidate in candidates {
                let key = candidate.lowercased()
                guard candidate.localizedCaseInsensitiveContains(trimmedQuery),
                      !seen.contains(key)
                else { continue }
                seen.insert(key)
                results.append(candidate)
                if results.count >= 8 { return results }
            }
        }

        return results
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

    func logoURL(for businessId: String) -> URL? {
        businessLogoURLs[businessId]
    }

    func dismissError() {
        errorMessage = nil
    }

    func selectSuggestion(_ suggestion: String) {
        searchText = suggestion
        commitSearch()
    }

    func selectRecent(_ recent: String) {
        searchText = recent
        commitSearch()
    }

    func commitSearch() {
        let query = trimmedQuery
        guard !query.isEmpty else { return }

        var updated = recentSearches.filter { $0.caseInsensitiveCompare(query) != .orderedSame }
        updated.insert(query, at: 0)
        if updated.count > maxRecentSearches {
            updated = Array(updated.prefix(maxRecentSearches))
        }
        recentSearches = updated
        UserDefaults.standard.set(updated, forKey: recentSearchesKey)
    }

    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
    }

    func clearSearchText() {
        searchText = ""
    }
}
