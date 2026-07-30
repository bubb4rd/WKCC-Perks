import Foundation

final class MockPromotionSubmissionService: PromotionSubmissionServicing {
    private let store: MockPromotionSubmissionStore
    private let dealsStore: MockDealsStore

    init(
        store: MockPromotionSubmissionStore = .shared,
        dealsStore: MockDealsStore = .shared
    ) {
        self.store = store
        self.dealsStore = dealsStore
    }

    func fetchSubmissions(status: PromotionSubmissionStatus?) async throws -> [PromotionSubmissionRecord] {
        try await simulateNetworkDelay()
        return await MainActor.run {
            store.filtered(status: status)
        }
    }

    func fetchSubmission(id: String) async throws -> PromotionSubmissionRecord {
        try await simulateNetworkDelay()
        return try await MainActor.run {
            guard let record = store.record(id: id) else {
                throw PromotionSubmissionError.notFound
            }
            return record
        }
    }

    func submit(
        _ submission: PromotionSubmission,
        from member: MemberProfile,
        companyName: String
    ) async throws -> PromotionSubmissionRecord {
        try await simulateNetworkDelay()

        let record = PromotionSubmissionRecord(
            id: "sub-\(UUID().uuidString.prefix(8))",
            submittedAt: Date(),
            submitterMemberId: member.id,
            submitterName: member.fullName,
            companyId: member.companyId,
            companyName: companyName,
            status: .pending,
            reviewedAt: nil,
            reviewedByAdminId: nil,
            adminNotes: nil,
            submission: submission
        )

        return await MainActor.run {
            store.append(record)
        }
    }

    func updateSubmission(
        id: String,
        submission: PromotionSubmission,
        adminNotes: String?
    ) async throws -> PromotionSubmissionRecord {
        try await simulateNetworkDelay()

        return try await MainActor.run {
            guard var record = store.record(id: id) else {
                throw PromotionSubmissionError.notFound
            }
            guard record.status == .pending else {
                throw PromotionSubmissionError.invalidState
            }

            record.submission = submission
            if let adminNotes {
                record.adminNotes = adminNotes
            }

            return store.update(record)
        }
    }

    func approve(id: String, reviewedBy adminId: String) async throws -> PromotionSubmissionRecord {
        try await simulateNetworkDelay()

        return try await MainActor.run {
            guard var record = store.record(id: id) else {
                throw PromotionSubmissionError.notFound
            }
            guard record.status == .pending else {
                throw PromotionSubmissionError.invalidState
            }

            record.status = .approved
            record.reviewedAt = Date()
            record.reviewedByAdminId = adminId

            let dealId = "deal-sub-\(record.id)"
            let businessId = record.companyId ?? "biz-sub-\(record.id)"
            let summary = record.submission.makeDealSummary(
                id: dealId,
                businessId: businessId,
                businessName: record.companyName
            )
            let detail = record.submission.makeDealDetail(
                id: dealId,
                businessId: businessId,
                businessName: record.companyName
            )
            dealsStore.publish(summary: summary, detail: detail)

            return store.update(record)
        }
    }

    func reject(id: String, reviewedBy adminId: String, notes: String?) async throws -> PromotionSubmissionRecord {
        try await simulateNetworkDelay()

        return try await MainActor.run {
            guard var record = store.record(id: id) else {
                throw PromotionSubmissionError.notFound
            }
            guard record.status == .pending else {
                throw PromotionSubmissionError.invalidState
            }

            record.status = .rejected
            record.reviewedAt = Date()
            record.reviewedByAdminId = adminId
            if let notes, !notes.trimmingCharacters(in: .whitespaces).isEmpty {
                record.adminNotes = notes
            }

            return store.update(record)
        }
    }

    func pendingCount() async throws -> Int {
        try await simulateNetworkDelay(short: true)
        return await MainActor.run {
            store.pendingCount()
        }
    }

    private func simulateNetworkDelay(short: Bool = false) async throws {
        let delay: UInt64 = short ? 150_000_000 : 350_000_000
        try await Task.sleep(nanoseconds: delay)
    }
}
