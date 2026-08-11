import Foundation

/// Registers / unregisters APNs device tokens with the `perks` edge function.
enum PushDeviceTokenService {
    private struct TokenBody: Encodable {
        let token: String
    }

    static func register(token: String) async throws {
        _ = try await PerksAPIClient.request(
            method: .post,
            path: "device-tokens",
            body: TokenBody(token: token),
            as: PerksAPIClient.OkResponse.self
        )
    }

    static func unregister(token: String?) async {
        guard !AppConfig.useMockAuth else { return }
        do {
            if let token, !token.isEmpty {
                _ = try await PerksAPIClient.request(
                    method: .delete,
                    path: "device-tokens",
                    body: TokenBody(token: token),
                    as: PerksAPIClient.OkResponse.self
                )
            } else {
                _ = try await PerksAPIClient.request(
                    method: .delete,
                    path: "device-tokens",
                    as: PerksAPIClient.OkResponse.self
                )
            }
        } catch {
            // Best-effort on sign-out; ignore network/session errors.
        }
    }
}
