import Foundation

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

struct PromotionSubmission: Equatable, Codable, Hashable {
    var contactEmail: String = ""
    var contactPhone: String = ""
    var title: String = ""
    var category: DealCategory = .restaurantsFoodBeverages
    var shortDescription: String = ""
    var fullDescription: String = ""
    var terms: String = ""
    var redemptionInstructions: String = ""
    var redemptionCodeType: RedemptionCodeType = .none
    var redemptionCode: String = ""
    var startDate: Date = Date()
    var endDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
}

extension PromotionSubmission {
    var previewRedemptionCode: String? {
        guard redemptionCodeType.requiresCodeValue else { return nil }
        let code = redemptionCode.trimmingCharacters(in: .whitespaces)
        return code.isEmpty ? nil : code
    }

    var previewRedemptionInstructions: String {
        var instructions = redemptionInstructions.trimmingCharacters(in: .whitespaces)
        if redemptionCodeType != .none && redemptionCodeType != .promoCode {
            instructions += "\n\n\(redemptionCodeType.rawValue): \(redemptionCode)"
        }
        return instructions
    }

    func makeDealSummary(id: String, businessId: String, businessName: String) -> DealSummary {
        DealSummary(
            id: id,
            title: title.trimmingCharacters(in: .whitespaces),
            businessId: businessId,
            businessName: businessName,
            shortDescription: shortDescription.trimmingCharacters(in: .whitespaces),
            category: category,
            expirationDate: endDate,
            isFeatured: false,
            membersOnly: true
        )
    }

    func makeDealDetail(id: String, businessId: String, businessName: String) -> DealDetail {
        DealDetail(
            id: id,
            title: title.trimmingCharacters(in: .whitespaces),
            businessId: businessId,
            businessName: businessName,
            description: fullDescription.trimmingCharacters(in: .whitespaces),
            terms: terms.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : terms.trimmingCharacters(in: .whitespaces),
            redemptionInstructions: previewRedemptionInstructions,
            redemptionCode: previewRedemptionCode,
            startDate: startDate,
            expirationDate: endDate,
            category: category,
            imageURL: nil,
            membersOnly: true,
            isFeatured: false
        )
    }
}
