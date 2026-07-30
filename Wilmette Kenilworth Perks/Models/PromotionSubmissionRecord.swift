import Foundation

enum PromotionSubmissionStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case approved
    case rejected

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending: "Pending"
        case .approved: "Approved"
        case .rejected: "Rejected"
        }
    }
}

struct PromotionSubmissionRecord: Identifiable, Equatable, Codable, Hashable {
    let id: String
    let submittedAt: Date
    let submitterMemberId: String
    let submitterName: String
    let companyId: String?
    let companyName: String
    var status: PromotionSubmissionStatus
    var reviewedAt: Date?
    var reviewedByAdminId: String?
    var adminNotes: String?
    var submission: PromotionSubmission
}
