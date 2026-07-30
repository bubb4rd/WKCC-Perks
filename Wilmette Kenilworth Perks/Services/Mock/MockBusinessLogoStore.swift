import Foundation

/// In-memory + on-disk logo URLs for mock auth / business catalog.
enum MockBusinessLogoStore {
    private static let lock = NSLock()
    private static var urls: [String: URL] = [:]

    static func logoURL(for companyId: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = urls[companyId] {
            return cached
        }
        let fileURL = fileURL(for: companyId)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            urls[companyId] = fileURL
            return fileURL
        }
        return nil
    }

    @discardableResult
    static func setLogo(companyId: String, imageData: Data) throws -> URL {
        let fileURL = fileURL(for: companyId)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try imageData.write(to: fileURL, options: .atomic)

        lock.lock()
        urls[companyId] = fileURL
        lock.unlock()
        return fileURL
    }

    private static func fileURL(for companyId: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MockBusinessLogos", isDirectory: true)
        let safe = companyId.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent("\(safe).jpg")
    }
}
