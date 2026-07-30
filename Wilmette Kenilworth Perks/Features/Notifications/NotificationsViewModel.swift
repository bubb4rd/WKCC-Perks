import Foundation
import Observation

@Observable
@MainActor
final class NotificationsViewModel {
    private(set) var notifications: [AppNotification] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let notificationService: any NotificationServicing

    init(notificationService: any NotificationServicing = AppDependencies.shared.notificationService) {
        self.notificationService = notificationService
    }

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    func load(member: MemberProfile?, isAdmin: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            notifications = try await notificationService.fetchNotifications(for: member, isAdmin: isAdmin)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func markAsRead(_ notification: AppNotification) async {
        guard !notification.isRead else { return }

        do {
            try await notificationService.markAsRead(id: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index].isRead = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllAsRead(member: MemberProfile?, isAdmin: Bool) async {
        guard unreadCount > 0 else { return }

        do {
            try await notificationService.markAllAsRead(for: member, isAdmin: isAdmin)
            notifications = notifications.map { notification in
                var updated = notification
                updated.isRead = true
                return updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
