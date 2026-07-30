import Foundation

final class SupabasePromotionSubmissionService: PromotionSubmissionServicing {
    func fetchSubmissions(status: PromotionSubmissionStatus?) async throws -> [PromotionSubmissionRecord] {
        var query: [URLQueryItem] = []
        if let status {
            query.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        let rows: [PerksSubmissionRecordDTO] = try await PerksAPIClient.request(
            method: .get,
            path: "submissions",
            queryItems: query,
            as: [PerksSubmissionRecordDTO].self
        )
        return rows.map { $0.toModel() }
    }

    func fetchSubmission(id: String) async throws -> PromotionSubmissionRecord {
        do {
            let row: PerksSubmissionRecordDTO = try await PerksAPIClient.request(
                method: .get,
                path: "submissions/\(id)",
                as: PerksSubmissionRecordDTO.self
            )
            return row.toModel()
        } catch PerksAPIClient.RequestError.notFound {
            throw PromotionSubmissionError.notFound
        }
    }

    func submit(
        _ submission: PromotionSubmission,
        from member: MemberProfile,
        companyName: String
    ) async throws -> PromotionSubmissionRecord {
        struct Body: Encodable {
            let submission: PromotionSubmission
            let companyName: String
            let companyId: String?
            let submitterName: String
        }

        let row: PerksSubmissionRecordDTO = try await PerksAPIClient.request(
            method: .post,
            path: "submissions",
            body: Body(
                submission: submission,
                companyName: companyName,
                companyId: member.companyId,
                submitterName: member.fullName
            ),
            as: PerksSubmissionRecordDTO.self
        )
        return row.toModel()
    }

    func updateSubmission(
        id: String,
        submission: PromotionSubmission,
        adminNotes: String?
    ) async throws -> PromotionSubmissionRecord {
        struct Body: Encodable {
            let submission: PromotionSubmission
            let adminNotes: String?
        }

        do {
            let row: PerksSubmissionRecordDTO = try await PerksAPIClient.request(
                method: .patch,
                path: "submissions/\(id)",
                body: Body(submission: submission, adminNotes: adminNotes),
                as: PerksSubmissionRecordDTO.self
            )
            return row.toModel()
        } catch PerksAPIClient.RequestError.notFound {
            throw PromotionSubmissionError.notFound
        } catch PerksAPIClient.RequestError.invalidState {
            throw PromotionSubmissionError.invalidState
        }
    }

    func approve(id: String, reviewedBy adminId: String) async throws -> PromotionSubmissionRecord {
        _ = adminId
        do {
            let row: PerksSubmissionRecordDTO = try await PerksAPIClient.request(
                method: .post,
                path: "submissions/\(id)/approve",
                as: PerksSubmissionRecordDTO.self
            )
            return row.toModel()
        } catch PerksAPIClient.RequestError.notFound {
            throw PromotionSubmissionError.notFound
        } catch PerksAPIClient.RequestError.invalidState {
            throw PromotionSubmissionError.invalidState
        }
    }

    func reject(
        id: String,
        reviewedBy adminId: String,
        notes: String?
    ) async throws -> PromotionSubmissionRecord {
        _ = adminId
        struct Body: Encodable {
            let notes: String?
        }

        do {
            let row: PerksSubmissionRecordDTO = try await PerksAPIClient.request(
                method: .post,
                path: "submissions/\(id)/reject",
                body: Body(notes: notes),
                as: PerksSubmissionRecordDTO.self
            )
            return row.toModel()
        } catch PerksAPIClient.RequestError.notFound {
            throw PromotionSubmissionError.notFound
        } catch PerksAPIClient.RequestError.invalidState {
            throw PromotionSubmissionError.invalidState
        }
    }

    func pendingCount() async throws -> Int {
        let dto: PerksPendingCountDTO = try await PerksAPIClient.request(
            method: .get,
            path: "submissions/pending-count",
            as: PerksPendingCountDTO.self
        )
        return dto.count
    }
}
