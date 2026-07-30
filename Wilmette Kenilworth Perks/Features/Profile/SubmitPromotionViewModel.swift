import Foundation
import Observation

@Observable
@MainActor
final class SubmitPromotionViewModel {
    var submission = PromotionSubmission()
    private(set) var companyName: String = ""
    private(set) var isSubmitting = false
    var didSubmitSuccessfully = false
    private(set) var errorMessage: String?

    private let submissionService: any PromotionSubmissionServicing
    private var submitter: MemberProfile?

    init(submissionService: any PromotionSubmissionServicing = AppDependencies.shared.promotionSubmissionService) {
        self.submissionService = submissionService
    }

    func configure(member: MemberProfile?) {
        submitter = member
        companyName = member?.companyName ?? ""
        if submission.contactEmail.isEmpty {
            submission.contactEmail = member?.email ?? ""
        }
    }

    var hasCompanyOnFile: Bool {
        !companyName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canContinueFromCompany: Bool {
        hasCompanyOnFile
            && !submission.contactEmail.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canContinueFromOffer: Bool {
        !submission.title.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.shortDescription.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.fullDescription.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.redemptionInstructions.trimmingCharacters(in: .whitespaces).isEmpty
            && submission.endDate >= submission.startDate
            && (!submission.redemptionCodeType.requiresCodeValue
                || !submission.redemptionCode.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var isValid: Bool {
        canContinueFromCompany && canContinueFromOffer
    }

    func dismissError() {
        errorMessage = nil
    }

    var previewDealSummary: DealSummary {
        submission.makeDealSummary(
            id: "promotion-preview",
            businessId: "preview-business",
            businessName: companyName
        )
    }

    var previewDealDetail: DealDetail {
        submission.makeDealDetail(
            id: "promotion-preview",
            businessId: "preview-business",
            businessName: companyName
        )
    }

    func submit() async {
        guard isValid, !isSubmitting, let submitter else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            _ = try await submissionService.submit(submission, from: submitter, companyName: companyName)
            didSubmitSuccessfully = true
        } catch {
            errorMessage = "Unable to submit your promotion. Please try again."
        }

        isSubmitting = false
    }
}
