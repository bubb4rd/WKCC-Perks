import SwiftUI

struct MySubmissionsListView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = MySubmissionsViewModel()

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.filteredRecords.isEmpty && !hasAttemptedLoad {
                LoadingView(message: "Loading your perks...")
            } else {
                submissionsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .wkccPageBackground()
        .navigationTitle("Manage Perks")
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .refreshable {
            await viewModel.load(for: authManager.member?.id)
            hasAttemptedLoad = true
        }
        .task(id: "\(authManager.member?.id ?? "")-\(viewModel.selectedFilter.rawValue)") {
            await viewModel.load(for: authManager.member?.id)
            hasAttemptedLoad = true
        }
    }

    @State private var hasAttemptedLoad = false

    private var emptyMessage: String {
        switch viewModel.selectedFilter {
        case .all: "You haven't submitted any promotions yet."
        case .pending: "No pending submissions."
        case .approved: "No approved submissions yet."
        case .rejected: "No rejected submissions."
        }
    }

    private var submissionsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: WKCCSpacing.md) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                filterBar

                if viewModel.filteredRecords.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "No Submissions",
                        message: emptyMessage
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, WKCCSpacing.xl)
                } else {
                    ForEach(viewModel.filteredRecords) { record in
                        NavigationLink {
                            MySubmissionDetailView(record: record)
                        } label: {
                            MySubmissionRow(record: record)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WKCCSpacing.md)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WKCCSpacing.xs) {
                ForEach(PromotionSubmissionFilter.allCases) { filter in
                    Button {
                        viewModel.selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(WKCCTypography.captionBold)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, WKCCSpacing.sm)
                            .padding(.vertical, WKCCSpacing.xs)
                            .background(viewModel.selectedFilter == filter ? WKCCColors.primary : WKCCColors.cardBackground)
                            .foregroundStyle(viewModel.selectedFilter == filter ? WKCCColors.textOnPrimary : WKCCColors.textPrimary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(WKCCColors.primary.opacity(viewModel.selectedFilter == filter ? 0 : 0.15), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MySubmissionRow: View {
    let record: PromotionSubmissionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            HStack(alignment: .center, spacing: WKCCSpacing.xs) {
                SubmissionStatusBadge(status: record.status)
                Spacer(minLength: WKCCSpacing.xs)
                Text(record.submittedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)
            }

            Text(record.submission.title)
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(record.companyName)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
                .lineLimit(1)

            if record.status == .rejected,
               let notes = record.adminNotes?.trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty {
                Text("Includes chamber notes")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.error.opacity(0.85))
            }
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wkccCardStyle()
    }
}

#Preview {
    NavigationStack {
        MySubmissionsListView()
            .environment(AuthManager())
    }
}
