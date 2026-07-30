import Foundation
import Observation

@Observable
@MainActor
final class AdminSubmissionsViewModel {
    private(set) var records: [PromotionSubmissionRecord] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var selectedFilter: PromotionSubmissionFilter = .all

    private let submissionService: any PromotionSubmissionServicing

    init(submissionService: any PromotionSubmissionServicing = AppDependencies.shared.promotionSubmissionService) {
        self.submissionService = submissionService
    }

    var filteredRecords: [PromotionSubmissionRecord] {
        records
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            records = try await submissionService.fetchSubmissions(status: selectedFilter.status)
        } catch {
            errorMessage = "Unable to load submissions."
        }

        isLoading = false
    }

    func pendingCount() async -> Int {
        (try? await submissionService.pendingCount()) ?? 0
    }

    func dismissError() {
        errorMessage = nil
    }
}
