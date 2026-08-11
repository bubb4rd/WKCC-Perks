import Foundation
import Observation

@Observable
@MainActor
final class MySubmissionsViewModel {
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

    func load(for submitterMemberId: String?) async {
        isLoading = true
        errorMessage = nil
        records = []

        guard let submitterMemberId else {
            isLoading = false
            return
        }

        do {
            let fetched = try await submissionService.fetchSubmissions(status: selectedFilter.status)
            records = fetched.filter { $0.submitterMemberId == submitterMemberId }
        } catch {
            errorMessage = "Unable to load your submissions."
        }

        isLoading = false
    }

    func dismissError() {
        errorMessage = nil
    }
}
