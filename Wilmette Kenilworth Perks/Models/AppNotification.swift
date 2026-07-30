import Foundation

enum AppNotificationAudience: String, Codable, CaseIterable {
    case member
    case admin
}

enum AppNotificationKind: String, Codable, CaseIterable {
    case promotionApproved
    case promotionRejected
    case newPromotionSubmission
    case dealExpiringSoon

    var iconName: String {
        switch self {
        case .promotionApproved: "checkmark.circle.fill"
        case .promotionRejected: "xmark.circle.fill"
        case .newPromotionSubmission: "tray.full.fill"
        case .dealExpiringSoon: "clock.fill"
        }
    }
}

struct AppNotification: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let message: String
    let kind: AppNotificationKind
    let audience: AppNotificationAudience
    let createdAt: Date
    var isRead: Bool
    let recipientMemberId: String?
    let relatedEntityId: String?

    var relativeTimestamp: String {
        createdAt.formatted(.relative(presentation: .named))
    }
}
