import Foundation

final class SupabaseBusinessService: BusinessServicing {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = AppConfig.memberAuthBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
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
    }

    func fetchBusinesses() async throws -> [ChamberBusiness] {
        let rows: [BusinessDTO] = try await get(path: "businesses", as: [BusinessDTO].self)
        return rows.map { $0.toModel() }
    }

    func fetchBusiness(id: String) async throws -> ChamberBusiness {
        do {
            var components = URLComponents(
                url: baseURL.appending(path: "business"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [URLQueryItem(name: "id", value: id)]
            guard let url = components.url else {
                throw ContentError.notFound
            }
            let row: BusinessDTO = try await get(url: url, as: BusinessDTO.self)
            return row.toModel()
        } catch let error as BusinessRequestError where error == .notFound {
            throw ContentError.notFound
        }
    }

    func updateCompanyProfile(_ update: CompanyProfileUpdate) async throws -> ChamberBusiness {
        struct Body: Encodable {
            let category: String
            let shortDescription: String
            let websiteURL: String?
            let phone: String?
            let address: String?
            let addressPublic: Bool
        }

        let body = Body(
            category: update.category.rawValue,
            shortDescription: update.shortDescription,
            websiteURL: optional(update.websiteURLString),
            phone: optional(update.phone),
            address: optional(update.address),
            addressPublic: update.addressPublic
        )

        return try await post(path: "company-profile", body: body, as: BusinessDTO.self).toModel()
    }

    private func optional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func get<Response: Decodable>(path: String, as: Response.Type) async throws -> Response {
        try await get(url: baseURL.appending(path: path), as: Response.self)
    }

    private func get<Response: Decodable>(url: URL, as: Response.Type) async throws -> Response {
        try await get(url: url, as: Response.self, allowRetryAfterRefresh: true)
    }

    private func get<Response: Decodable>(
        url: URL,
        as: Response.Type,
        allowRetryAfterRefresh: Bool
    ) async throws -> Response {
        let accessToken = try await MemberSessionAccess.accessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BusinessRequestError.badResponse
        }

        switch http.statusCode {
        case 200..<300:
            return try decoder.decode(Response.self, from: data)
        case 401 where allowRetryAfterRefresh:
            _ = try await MemberSessionAccess.accessToken(forceRefresh: true)
            return try await get(url: url, as: Response.self, allowRetryAfterRefresh: false)
        case 401, 403:
            throw BusinessRequestError.unauthorized
        case 404:
            throw BusinessRequestError.notFound
        default:
            let message = (try? decoder.decode(APIError.self, from: data))?.error
            throw BusinessRequestError.server(message ?? "Failed to load businesses.")
        }
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        as: Response.Type,
        allowRetryAfterRefresh: Bool = true
    ) async throws -> Response {
        let accessToken = try await MemberSessionAccess.accessToken()
        let url = baseURL.appending(path: path)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BusinessRequestError.badResponse
        }

        switch http.statusCode {
        case 200..<300:
            return try decoder.decode(Response.self, from: data)
        case 401 where allowRetryAfterRefresh:
            _ = try await MemberSessionAccess.accessToken(forceRefresh: true)
            return try await post(
                path: path,
                body: body,
                as: Response.self,
                allowRetryAfterRefresh: false
            )
        case 401, 403:
            throw BusinessRequestError.unauthorized
        case 404:
            throw BusinessRequestError.notFound
        default:
            let message = (try? decoder.decode(APIError.self, from: data))?.error
            throw BusinessRequestError.server(message ?? "Couldn't save business profile.")
        }
    }
}

private enum BusinessRequestError: LocalizedError, Equatable {
    case unauthorized
    case notFound
    case badResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Sign in again to continue."
        case .notFound:
            "Business not found."
        case .badResponse:
            "Unexpected server response."
        case .server(let message):
            message
        }
    }
}

private struct APIError: Decodable {
    let error: String?
}

private struct BusinessDTO: Decodable {
    let id: String
    let name: String
    let category: String
    let shortDescription: String
    let fullDescription: String?
    let logoURL: String?
    let websiteURL: String?
    let phone: String?
    let address: String?
    let addressPublic: Bool?
    let email: String?
    let latitude: Double?
    let longitude: Double?
    let memberSince: Date?
    let isChamberPartner: Bool
    let activeDeals: [DealSummaryDTO]
    let redemptionNotes: String?

    func toModel() -> ChamberBusiness {
        ChamberBusiness(
            id: id,
            name: name,
            category: DealCategory(rawValue: category) ?? .other,
            shortDescription: shortDescription,
            fullDescription: fullDescription,
            logoURL: logoURL.flatMap(URL.init(string:)),
            websiteURL: websiteURL.flatMap(URL.init(string:)),
            phone: phone,
            address: address,
            addressPublic: addressPublic ?? true,
            email: email,
            latitude: latitude,
            longitude: longitude,
            memberSince: memberSince,
            isChamberPartner: isChamberPartner,
            activeDeals: activeDeals.map { $0.toModel() },
            redemptionNotes: redemptionNotes
        )
    }
}

private struct DealSummaryDTO: Decodable {
    let id: String
    let title: String
    let businessId: String
    let businessName: String
    let shortDescription: String
    let category: String
    let expirationDate: Date?
    let isFeatured: Bool
    let membersOnly: Bool

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
            membersOnly: membersOnly
        )
    }
}
