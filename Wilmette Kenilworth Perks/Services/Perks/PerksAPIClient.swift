import Foundation

/// Shared HTTP client for the Supabase `perks` edge function.
/// Auth: `apikey` = anon key; `Authorization` = member session access token.
enum PerksAPIClient {
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
    }

    struct APIErrorBody: Decodable {
        let error: String?
    }

    enum RequestError: LocalizedError {
        case missingSession
        case notFound
        case invalidState
        case http(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .missingSession:
                "Sign in again to continue."
            case .notFound:
                "Content not found."
            case .invalidState:
                "This item can no longer be updated."
            case .http(_, let message):
                message
            }
        }
    }

    private static let session = URLSession.shared

    private static let decoder: JSONDecoder = {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = fractional.date(from: value) ?? plain.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(value)"
            )
        }
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static func request<Response: Decodable>(
        method: Method,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        as: Response.Type
    ) async throws -> Response {
        try await perform(
            method: method,
            path: path,
            queryItems: queryItems,
            body: body,
            as: Response.self,
            allowRetryAfterRefresh: true
        )
    }

    private static func perform<Response: Decodable>(
        method: Method,
        path: String,
        queryItems: [URLQueryItem],
        body: (any Encodable)?,
        as: Response.Type,
        allowRetryAfterRefresh: Bool
    ) async throws -> Response {
        let accessToken = try await MemberSessionAccess.accessToken()

        var url = AppConfig.perksBaseURL
        for segment in path.split(separator: "/").map(String.init) where !segment.isEmpty {
            url = url.appending(path: segment)
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let requestURL = components.url else {
            throw RequestError.http(status: 0, message: "Invalid request URL.")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method.rawValue
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if (200..<300).contains(http.statusCode) {
            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw RequestError.http(
                    status: http.statusCode,
                    message: "Could not read server response."
                )
            }
        }

        if http.statusCode == 401, allowRetryAfterRefresh {
            _ = try await MemberSessionAccess.accessToken(forceRefresh: true)
            return try await perform(
                method: method,
                path: path,
                queryItems: queryItems,
                body: body,
                as: Response.self,
                allowRetryAfterRefresh: false
            )
        }

        let message = (try? decoder.decode(APIErrorBody.self, from: data))?.error
            ?? "Request failed. Please try again."

        switch http.statusCode {
        case 404:
            throw RequestError.notFound
        case 409:
            throw RequestError.invalidState
        default:
            throw RequestError.http(status: http.statusCode, message: message)
        }
    }
}

private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ wrapped: any Encodable) {
        encodeFunc = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

// MARK: - Wire DTOs (tolerant category / URL mapping)

struct PerksDealSummaryDTO: Decodable {
    let id: String
    let title: String
    let businessId: String
    let businessName: String
    let shortDescription: String
    let category: String
    let expirationDate: Date?
    let isFeatured: Bool
    let membersOnly: Bool
    let archivedAt: Date?

    func toModel() -> DealSummary {
        DealSummary(
            id: id,
            title: title,
            businessId: businessId,
            businessName: businessName,
            shortDescription: shortDescription,
            category: DealCategory(rawValue: category) ?? .other,
            expirationDate: expirationDate,
            isFeatured: isFeatured,
            membersOnly: membersOnly,
            archivedAt: archivedAt
        )
    }
}

struct PerksDealDetailDTO: Decodable {
    let id: String
    let title: String
    let businessId: String
    let businessName: String
    let description: String
    let terms: String?
    let redemptionInstructions: String
    let redemptionCode: String?
    let startDate: Date?
    let expirationDate: Date?
    let category: String
    let imageURL: String?
    let membersOnly: Bool
    let isFeatured: Bool
    let archivedAt: Date?

    func toModel() -> DealDetail {
        DealDetail(
            id: id,
            title: title,
            businessId: businessId,
            businessName: businessName,
            description: description,
            terms: terms,
            redemptionInstructions: redemptionInstructions,
            redemptionCode: redemptionCode,
            startDate: startDate,
            expirationDate: expirationDate,
            category: DealCategory(rawValue: category) ?? .other,
            imageURL: imageURL.flatMap { URL(string: $0) },
            membersOnly: membersOnly,
            isFeatured: isFeatured,
            archivedAt: archivedAt
        )
    }
}

struct PerksSubmissionRecordDTO: Decodable {
    let id: String
    let submittedAt: Date
    let submitterMemberId: String
    let submitterName: String
    let companyId: String?
    let companyName: String
    let status: PromotionSubmissionStatus
    let reviewedAt: Date?
    let reviewedByAdminId: String?
    let adminNotes: String?
    let submission: PromotionSubmission

    func toModel() -> PromotionSubmissionRecord {
        PromotionSubmissionRecord(
            id: id,
            submittedAt: submittedAt,
            submitterMemberId: submitterMemberId,
            submitterName: submitterName,
            companyId: companyId,
            companyName: companyName,
            status: status,
            reviewedAt: reviewedAt,
            reviewedByAdminId: reviewedByAdminId,
            adminNotes: adminNotes,
            submission: submission
        )
    }
}

struct PerksPendingCountDTO: Decodable {
    let count: Int
}
