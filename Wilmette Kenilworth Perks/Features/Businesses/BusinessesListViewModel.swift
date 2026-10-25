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
        } catch let error where error.isCancellation {
            // Cancelled by SwiftUI (e.g. mid-refresh); keep the current list, not a failure.
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
