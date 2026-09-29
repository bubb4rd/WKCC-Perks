import Foundation
import Observation

@Observable
@MainActor
final class BusinessesListViewModel {
    private(set) var businesses: [ChamberBusiness] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var searchText = ""
    var selectedCategory: DealCategory?

    private let businessService: any BusinessServicing

    init(businessService: any BusinessServicing = AppDependencies.shared.businessService) {
        self.businessService = businessService
    }

    var filteredBusinesses: [ChamberBusiness] {
        businesses.filter { business in
            let matchesSearch = searchText.isEmpty
                || business.name.localizedCaseInsensitiveContains(searchText)
                || business.shortDescription.localizedCaseInsensitiveContains(searchText)

            let matchesCategory = selectedCategory == nil || business.category == selectedCategory

            return matchesSearch && matchesCategory
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            businesses = try await businessService.fetchBusinesses()
        } catch is CancellationError {
            // Superseded load; keep the current list without surfacing an error.
        } catch let error as URLError where error.code == .cancelled {
            // Same as above for URLSession-backed services.
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleCategory(_ category: DealCategory) {
        selectedCategory = selectedCategory == category ? nil : category
    }

    func dismissError() {
        errorMessage = nil
    }
}
