import Foundation
import Security

enum KeychainStore {
    private static let service = "com.wkcc.perks.auth"

    static func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        try saveData(data, account: "authSession")
    }

    static func loadSession() -> AuthSession? {
        guard let data = loadData(account: "authSession") else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    static func clear() {
        delete(account: "authSession")
    }

    private static func saveData(_ data: Data, account: String) throws {
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainStore", code: Int(status))
        }
    }

    private static func loadData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
