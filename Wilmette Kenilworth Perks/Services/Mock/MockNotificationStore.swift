import Foundation

@MainActor
final class MockNotificationStore {
    static let shared = MockNotificationStore()

    private(set) var notifications: [AppNotification]

    private init() {
        notifications = MockData.seedNotifications
    }

    func visibleNotifications(for member: MemberProfile?, isAdmin: Bool) -> [AppNotification] {
        let memberId = member?.id

        return notifications
            .filter { notification in
                switch notification.audience {
                case .member:
                    guard let memberId else { return false }
                    return notification.recipientMemberId == memberId
                case .admin:
                    return isAdmin
                }
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func notification(id: String) -> AppNotification? {
        notifications.first { $0.id == id }
    }

    @discardableResult
    func update(_ notification: AppNotification) -> AppNotification {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else {
            return notification
        }
        notifications[index] = notification
        return notification
    }

    func markAllAsRead(for member: MemberProfile?, isAdmin: Bool) {
        let visibleIDs = Set(visibleNotifications(for: member, isAdmin: isAdmin).map(\.id))
        for index in notifications.indices where visibleIDs.contains(notifications[index].id) {
            notifications[index].isRead = true
        }
    }

    func resetToSeedData() {
        notifications = MockData.seedNotifications
    }
}
