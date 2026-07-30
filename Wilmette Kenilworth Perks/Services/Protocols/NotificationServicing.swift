import Foundation

protocol NotificationServicing {
    func fetchNotifications(for member: MemberProfile?, isAdmin: Bool) async throws -> [AppNotification]
    func markAsRead(id: String) async throws
    func markAllAsRead(for member: MemberProfile?, isAdmin: Bool) async throws
}

enum NotificationServiceError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: "Notification not found."
        }
    }
}
