import Foundation
import Observation

@Observable
@MainActor
final class AdminPerksListViewModel {
    private(set) var perks: [DealSummary] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var activePerks: [DealSummary] {
        perks.filter { !$0.isArchived }
    }

    var archivedPerks: [DealSummary] {
        perks.filter(\.isArchived)
    }

    private let perksAdminService: any PerksAdminServicing

    init(perksAdminService: any PerksAdminServicing = AppDependencies.shared.perksAdminService) {
        self.perksAdminService = perksAdminService
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            perks = try await perksAdminService.fetchAllPerks()
        } catch {
            errorMessage = "Unable to load perks."
        }

        isLoading = false
    }

    func dismissError() {
        errorMessage = nil
    }
}
