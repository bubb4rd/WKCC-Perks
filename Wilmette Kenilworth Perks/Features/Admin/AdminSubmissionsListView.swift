import SwiftUI

struct AdminSubmissionsListView: View {
    var isEmbedded = false

    @State private var viewModel = AdminSubmissionsViewModel()

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.records.isEmpty {
                LoadingView(message: "Loading submissions...")
            } else if viewModel.filteredRecords.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "No Submissions",
                    message: emptyMessage
                )
            } else {
                submissionsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .wkccPageBackground()
        .modifier(AdminSubmissionsNavigationModifier(isEmbedded: isEmbedded))
        .refreshable {
            await viewModel.load()
        }
        .task(id: viewModel.selectedFilter) {
            await viewModel.load()
        }
        .onAppear {
            Task { await viewModel.load() }
        }
    }

    private var emptyMessage: String {
        switch viewModel.selectedFilter {
        case .all: "No promotion submissions yet."
        case .pending: "No pending submissions to review."
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

                ForEach(viewModel.filteredRecords) { record in
                    NavigationLink {
                        AdminSubmissionDetailView(record: record)
                    } label: {
                        AdminSubmissionRow(record: record)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

private struct AdminSubmissionsNavigationModifier: ViewModifier {
    let isEmbedded: Bool

    func body(content: Content) -> some View {
        if isEmbedded {
            content
        } else {
            content
                .navigationTitle("Submissions")
                .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

private struct AdminSubmissionRow: View {
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

            Text("Submitted by \(record.submitterName)")
                .font(WKCCTypography.caption)
                .foregroundStyle(WKCCColors.textSecondary)
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wkccCardStyle()
    }
}

struct SubmissionStatusBadge: View {
    let status: PromotionSubmissionStatus

    var body: some View {
        BadgeLabel(text: status.displayName, color: badgeColor)
    }

    private var badgeColor: Color {
        switch status {
        case .pending: WKCCColors.primary
        case .approved: WKCCColors.accent
        case .rejected: WKCCColors.error
        }
    }
}

#Preview {
    NavigationStack {
        AdminSubmissionsListView()
    }
}
