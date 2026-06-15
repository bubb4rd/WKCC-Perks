import Foundation
import Observation

enum RedemptionCodeType: String, CaseIterable, Identifiable, Codable {
    case none = "No code needed"
    case promoCode = "Promo code"
    case barcode = "Barcode"
    case qrCode = "QR code"
    case other = "Other"

    var id: String { rawValue }

    var codeFieldLabel: String {
        switch self {
        case .none: ""
        case .promoCode: "Promo Code"
        case .barcode: "Barcode Number"
        case .qrCode: "QR Code Content"
        case .other: "Code Details"
        }
    }

    var codeFieldPlaceholder: String {
        switch self {
        case .none: ""
        case .promoCode: "e.g. WKCC-SAVE20"
        case .barcode: "e.g. 012345678905"
        case .qrCode: "URL or text encoded in the QR code"
        case .other: "Describe the code members should use"
        }
    }

    var requiresCodeValue: Bool {
        self != .none
    }
}

struct PromotionSubmission: Equatable {
    var contactEmail: String = ""
    var contactPhone: String = ""
    var title: String = ""
    var category: DealCategory = .dining
    var shortDescription: String = ""
    var fullDescription: String = ""
    var terms: String = ""
    var redemptionInstructions: String = ""
    var redemptionCodeType: RedemptionCodeType = .none
    var redemptionCode: String = ""
    var startDate: Date = Date()
    var endDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
}

@Observable
@MainActor
final class SubmitPromotionViewModel {
    var submission = PromotionSubmission()
    private(set) var companyName: String = ""
    private(set) var isSubmitting = false
    var didSubmitSuccessfully = false
    private(set) var errorMessage: String?

    func configure(member: MemberProfile?) {
        companyName = member?.companyName ?? ""
        if submission.contactEmail.isEmpty {
            submission.contactEmail = member?.email ?? ""
        }
    }

    var hasCompanyOnFile: Bool {
        !companyName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isValid: Bool {
        hasCompanyOnFile
            && !submission.title.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.shortDescription.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.fullDescription.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.redemptionInstructions.trimmingCharacters(in: .whitespaces).isEmpty
            && !submission.contactEmail.trimmingCharacters(in: .whitespaces).isEmpty
            && submission.endDate >= submission.startDate
            && (!submission.redemptionCodeType.requiresCodeValue
                || !submission.redemptionCode.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    func dismissError() {
        errorMessage = nil
    }

    var previewDealSummary: DealSummary {
        DealSummary(
            id: "promotion-preview",
            title: submission.title.trimmingCharacters(in: .whitespaces),
            businessId: "preview-business",
            businessName: companyName,
            shortDescription: submission.shortDescription.trimmingCharacters(in: .whitespaces),
            category: submission.category,
            expirationDate: submission.endDate,
            isFeatured: false,
            membersOnly: true
        )
    }

    var previewDealDetail: DealDetail {
        DealDetail(
            id: "promotion-preview",
            title: submission.title.trimmingCharacters(in: .whitespaces),
            businessId: "preview-business",
            businessName: companyName,
            description: submission.fullDescription.trimmingCharacters(in: .whitespaces),
            terms: submission.terms.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : submission.terms.trimmingCharacters(in: .whitespaces),
            redemptionInstructions: previewRedemptionInstructions,
            redemptionCode: previewRedemptionCode,
            startDate: submission.startDate,
            expirationDate: submission.endDate,
            category: submission.category,
            imageURL: nil,
            membersOnly: true,
            isFeatured: false
        )
    }

    private var previewRedemptionCode: String? {
        guard submission.redemptionCodeType.requiresCodeValue else { return nil }
        let code = submission.redemptionCode.trimmingCharacters(in: .whitespaces)
        return code.isEmpty ? nil : code
    }

    private var previewRedemptionInstructions: String {
        var instructions = submission.redemptionInstructions.trimmingCharacters(in: .whitespaces)
        if submission.redemptionCodeType != .none && submission.redemptionCodeType != .promoCode {
            instructions += "\n\n\(submission.redemptionCodeType.rawValue): \(submission.redemptionCode)"
        }
        return instructions
    }

    func submit() async {
        guard isValid, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            try await Task.sleep(nanoseconds: 900_000_000)
            didSubmitSuccessfully = true
        } catch {
            errorMessage = "Unable to submit your promotion. Please try again."
        }

        isSubmitting = false
    }
}
