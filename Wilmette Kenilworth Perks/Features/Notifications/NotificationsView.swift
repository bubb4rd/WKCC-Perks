import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: NotificationsViewModel
    let member: MemberProfile?
    let isAdmin: Bool

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    LoadingView(message: "Loading notifications...")
                } else if viewModel.notifications.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "No Notifications",
                        message: "You're all caught up. New updates will appear here."
                    )
                } else {
                    notificationsList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.unreadCount > 0 {
                        Button("Mark All Read") {
                            Task {
                                await viewModel.markAllAsRead(member: member, isAdmin: isAdmin)
                            }
                        }
                        .font(WKCCTypography.captionBold)
                    }
                }
            }
            .refreshable {
                await viewModel.load(member: member, isAdmin: isAdmin)
            }
            .task {
                await viewModel.load(member: member, isAdmin: isAdmin)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var notificationsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                if isAdmin {
                    notificationSection(
                        title: "Admin",
                        notifications: viewModel.notifications.filter { $0.audience == .admin }
                    )
                }

                notificationSection(
                    title: isAdmin ? "Your Updates" : "Updates",
                    notifications: viewModel.notifications.filter { $0.audience == .member }
                )
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
    }

    @ViewBuilder
    private func notificationSection(title: String, notifications: [AppNotification]) -> some View {
        if !notifications.isEmpty {
            VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
                Text(title)
                    .font(WKCCTypography.captionBold)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .textCase(.uppercase)

                ForEach(notifications) { notification in
                    Button {
                        Task {
                            await viewModel.markAsRead(notification)
                        }
                    } label: {
                        NotificationRow(notification: notification)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: WKCCSpacing.sm) {
            Image(systemName: notification.kind.iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(notification.title)
                        .font(notification.isRead ? WKCCTypography.callout : WKCCTypography.callout.weight(.semibold))
                        .foregroundStyle(WKCCColors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: WKCCSpacing.xs)

                    Text(notification.relativeTimestamp)
                        .font(WKCCTypography.caption)
                        .foregroundStyle(WKCCColors.textSecondary)
                }

                Text(notification.message)
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !notification.isRead {
                Circle()
                    .fill(WKCCColors.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(notification.isRead ? WKCCColors.cardBackground : WKCCColors.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: WKCCRadius.lg)
                .stroke(WKCCColors.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var iconColor: Color {
        switch notification.kind {
        case .promotionApproved:
            WKCCColors.accent
        case .promotionRejected:
            WKCCColors.error
        case .newPromotionSubmission:
            WKCCColors.primary
        case .dealExpiringSoon:
            WKCCColors.warning
        }
    }
}

#Preview("Member") {
    NotificationsView(
        viewModel: NotificationsViewModel(),
        member: MockData.sampleMember,
        isAdmin: false
    )
}

#Preview("Admin") {
    NotificationsView(
        viewModel: NotificationsViewModel(),
        member: MockData.adminMember,
        isAdmin: true
    )
}
