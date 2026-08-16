import Foundation

final class MockPromotionSubmissionService: PromotionSubmissionServicing {
    private let storeOverride: MockPromotionSubmissionStore?
    private let dealsStoreOverride: MockDealsStore?

    init(
        store: MockPromotionSubmissionStore? = nil,
        dealsStore: MockDealsStore? = nil
    ) {
        self.storeOverride = store
        self.dealsStoreOverride = dealsStore
    }

    @MainActor
    private func resolvedStore() -> MockPromotionSubmissionStore {
        storeOverride ?? .shared
    }

    @MainActor
    private func resolvedDealsStore() -> MockDealsStore {
        dealsStoreOverride ?? .shared
    }

    func fetchSubmissions(status: PromotionSubmissionStatus?) async throws -> [PromotionSubmissionRecord] {
        try await simulateNetworkDelay()
        return await MainActor.run {
            resolvedStore().filtered(status: status)
        }
    }

    func fetchSubmission(id: String) async throws -> PromotionSubmissionRecord {
        try await simulateNetworkDelay()
        return try await MainActor.run {
            guard let record = resolvedStore().record(id: id) else {
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
            resolvedStore().append(record)
        }
    }

    func updateSubmission(
        id: String,
        submission: PromotionSubmission,
        adminNotes: String?
    ) async throws -> PromotionSubmissionRecord {
        try await simulateNetworkDelay()

        return try await MainActor.run {
            guard var record = resolvedStore().record(id: id) else {
                throw PromotionSubmissionError.notFound
            }
            guard record.status == .pending else {
                throw PromotionSubmissionError.invalidState
            }

            record.submission = submission
            if let adminNotes {
                record.adminNotes = adminNotes
            }

            return resolvedStore().update(record)
        }
    }

    func approve(id: String, reviewedBy adminId: String) async throws -> PromotionSubmissionRecord {
        try await simulateNetworkDelay()

        return try await MainActor.run {
            guard var record = resolvedStore().record(id: id) else {
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
            resolvedDealsStore().publish(summary: summary, detail: detail)

            return resolvedStore().update(record)
        }
    }

    func reject(id: String, reviewedBy adminId: String, notes: String?) async throws -> PromotionSubmissionRecord {
        try await simulateNetworkDelay()

        return try await MainActor.run {
            guard var record = resolvedStore().record(id: id) else {
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

            return resolvedStore().update(record)
        }
    }

    func pendingCount() async throws -> Int {
        try await simulateNetworkDelay(short: true)
        return await MainActor.run {
            resolvedStore().pendingCount()
        }
    }

    private func simulateNetworkDelay(short: Bool = false) async throws {
        let delay: UInt64 = short ? 150_000_000 : 350_000_000
        try await Task.sleep(nanoseconds: delay)
    }
}
