import Foundation

enum PromotionSubmissionFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pending = "Pending"
    case approved = "Approved"
    case rejected = "Rejected"

    var id: String { rawValue }

    var status: PromotionSubmissionStatus? {
        switch self {
        case .all: nil
        case .pending: .pending
        case .approved: .approved
        case .rejected: .rejected
        }
    }
}

protocol PromotionSubmissionServicing {
    func fetchSubmissions(status: PromotionSubmissionStatus?) async throws -> [PromotionSubmissionRecord]
    func fetchSubmission(id: String) async throws -> PromotionSubmissionRecord
    func submit(_ submission: PromotionSubmission, from member: MemberProfile, companyName: String) async throws -> PromotionSubmissionRecord
    func updateSubmission(id: String, submission: PromotionSubmission, adminNotes: String?) async throws -> PromotionSubmissionRecord
    func approve(id: String, reviewedBy adminId: String) async throws -> PromotionSubmissionRecord
    func reject(id: String, reviewedBy adminId: String, notes: String?) async throws -> PromotionSubmissionRecord
    func pendingCount() async throws -> Int
}

enum PromotionSubmissionError: LocalizedError {
    case notFound
    case invalidState

    var errorDescription: String? {
        switch self {
        case .notFound: "Submission not found."
        case .invalidState: "This submission can no longer be updated."
        }
    }
}
