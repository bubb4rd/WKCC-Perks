import Foundation

@MainActor
final class MockPromotionSubmissionStore {
    static let shared = MockPromotionSubmissionStore()

    private(set) var records: [PromotionSubmissionRecord]

    private init() {
        records = MockData.seedPromotionSubmissions
    }

    func record(id: String) -> PromotionSubmissionRecord? {
        records.first { $0.id == id }
    }

    func filtered(status: PromotionSubmissionStatus?) -> [PromotionSubmissionRecord] {
        guard let status else { return records.sorted { $0.submittedAt > $1.submittedAt } }
        return records
            .filter { $0.status == status }
            .sorted { $0.submittedAt > $1.submittedAt }
    }

    func pendingCount() -> Int {
        records.filter { $0.status == .pending }.count
    }

    @discardableResult
    func append(_ record: PromotionSubmissionRecord) -> PromotionSubmissionRecord {
        records.insert(record, at: 0)
        return record
    }

    @discardableResult
    func update(_ record: PromotionSubmissionRecord) -> PromotionSubmissionRecord {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return record }
        records[index] = record
        return record
    }

    func resetToSeedData() {
        records = MockData.seedPromotionSubmissions
    }
}
