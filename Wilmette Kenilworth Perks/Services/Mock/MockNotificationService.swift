import Foundation

final class MockNotificationService: NotificationServicing {
    private let storeOverride: MockNotificationStore?

    init(store: MockNotificationStore? = nil) {
        self.storeOverride = store
    }

    func fetchNotifications(for member: MemberProfile?, isAdmin: Bool) async throws -> [AppNotification] {
        try await simulateNetworkDelay(short: true)
        return await MainActor.run {
            resolvedStore().visibleNotifications(for: member, isAdmin: isAdmin)
        }
    }

    func markAsRead(id: String) async throws {
        try await simulateNetworkDelay(short: true)

        try await MainActor.run {
            let store = resolvedStore()
            guard var notification = store.notification(id: id) else {
                throw NotificationServiceError.notFound
            }
            notification.isRead = true
            store.update(notification)
        }
    }

    func markAllAsRead(for member: MemberProfile?, isAdmin: Bool) async throws {
        try await simulateNetworkDelay(short: true)
        await MainActor.run {
            resolvedStore().markAllAsRead(for: member, isAdmin: isAdmin)
        }
    }

    @MainActor
    private func resolvedStore() -> MockNotificationStore {
        storeOverride ?? .shared
    }

    private func simulateNetworkDelay(short: Bool = false) async throws {
        let delay: UInt64 = short ? 150_000_000 : 350_000_000
        try await Task.sleep(nanoseconds: delay)
    }
}
