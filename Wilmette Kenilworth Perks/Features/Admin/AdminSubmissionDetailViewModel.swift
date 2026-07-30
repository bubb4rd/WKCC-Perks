import Foundation
import Observation

@Observable
@MainActor
final class AdminSubmissionDetailViewModel {
    var record: PromotionSubmissionRecord
    private(set) var isSaving = false
    private(set) var isReviewing = false
    private(set) var errorMessage: String?
    var adminNotes: String

    private let submissionService: any PromotionSubmissionServicing

    init(
        record: PromotionSubmissionRecord,
        submissionService: any PromotionSubmissionServicing = AppDependencies.shared.promotionSubmissionService
    ) {
        self.record = record
        self.adminNotes = record.adminNotes ?? ""
        self.submissionService = submissionService
    }

    var isPending: Bool {
        record.status == .pending
    }

    var isValid: Bool {
        let submission = record.submission
        return !submission.title.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.shortDescription.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.fullDescription.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.redemptionInstructions.trimmingCharacters(in: .whitespaces).isEmpty
            && submission.endDate >= submission.startDate
            && (!submission.redemptionCodeType.requiresCodeValue
                || !submission.redemptionCode.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    func dismissError() {
        errorMessage = nil
    }

    func saveChanges() async -> Bool {
        guard isPending, isValid, !isSaving else { return false }
        isSaving = true
        errorMessage = nil

        do {
            record = try await submissionService.updateSubmission(
                id: record.id,
                submission: record.submission,
                adminNotes: adminNotes
            )
            isSaving = false
            return true
        } catch {
            errorMessage = "Unable to save changes."
            isSaving = false
            return false
        }
    }

    func approve(reviewedBy adminId: String) async -> Bool {
        guard isPending, !isReviewing else { return false }
        isReviewing = true
        errorMessage = nil

        do {
            if isValid {
                _ = try await submissionService.updateSubmission(
                    id: record.id,
                    submission: record.submission,
                    adminNotes: adminNotes
                )
            }
            record = try await submissionService.approve(id: record.id, reviewedBy: adminId)
            isReviewing = false
            return true
        } catch {
            errorMessage = "Unable to approve this submission."
            isReviewing = false
            return false
        }
    }

    func reject(reviewedBy adminId: String) async -> Bool {
        guard isPending, !isReviewing else { return false }
        isReviewing = true
        errorMessage = nil

        do {
            record = try await submissionService.reject(
                id: record.id,
                reviewedBy: adminId,
                notes: adminNotes
            )
            isReviewing = false
            return true
        } catch {
            errorMessage = "Unable to reject this submission."
            isReviewing = false
            return false
        }
    }
}
