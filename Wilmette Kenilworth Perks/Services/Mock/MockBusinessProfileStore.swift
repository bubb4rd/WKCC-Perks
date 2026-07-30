import Foundation

/// In-memory member-owned business profile fields for mock mode.
enum MockBusinessProfileStore {
    private static let lock = NSLock()
    private static var profiles: [String: CompanyProfileUpdate] = [:]

    static func profile(for companyId: String) -> CompanyProfileUpdate? {
        lock.lock()
        defer { lock.unlock() }
        return profiles[companyId]
    }

    static func setProfile(_ update: CompanyProfileUpdate, for companyId: String) {
        lock.lock()
        profiles[companyId] = update
        lock.unlock()
    }
}
