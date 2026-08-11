import SwiftUI

struct MySubmissionDetailView: View {
    let record: PromotionSubmissionRecord

    var body: some View {
        MySubmissionDetailContent(record: record)
    }
}

private struct MySubmissionDetailContent: View {
    @State private var submission: PromotionSubmission
    private let record: PromotionSubmissionRecord

    init(record: PromotionSubmissionRecord) {
        self.record = record
        _submission = State(initialValue: record.submission)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                metadataSection

                if shouldShowChamberNotes {
                    chamberNotesSection
                }

                PromotionSubmissionForm(
                    submission: $submission,
                    companyName: record.companyName,
                    isReadOnly: true,
                    showCompanySection: false
                )
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
        .navigationTitle("Submission")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var shouldShowChamberNotes: Bool {
        guard let notes = record.adminNotes?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !notes.isEmpty
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            HStack {
                SubmissionStatusBadge(status: record.status)
                Spacer()
            }

            Text(record.companyName)
                .font(WKCCTypography.sectionTitle)
                .foregroundStyle(WKCCColors.textPrimary)

            Text(record.submission.title)
                .font(WKCCTypography.callout.weight(.medium))
                .foregroundStyle(WKCCColors.textSecondary)

            Text("Submitted \(record.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(WKCCTypography.caption)
                .foregroundStyle(WKCCColors.textSecondary.opacity(0.75))

            if let reviewedAt = record.reviewedAt {
                HStack(spacing: WKCCSpacing.xxs) {
                    Image(systemName: record.status == .approved ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(WKCCTypography.caption)
                        .foregroundStyle(
                            record.status == .approved
                                ? WKCCColors.accent.opacity(0.85)
                                : WKCCColors.error.opacity(0.75)
                        )

                    Text("Reviewed \(reviewedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(WKCCTypography.caption)
                        .foregroundStyle(WKCCColors.textSecondary.opacity(0.65))
                }
            }
        }
    }

    private var chamberNotesSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            Text(notesSectionTitle)
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            Text(record.adminNotes ?? "")
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WKCCSpacing.md)
                .wkccCardStyle()
        }
    }

    private var notesSectionTitle: String {
        record.status == .rejected ? "Why it was rejected" : "Chamber notes"
    }
}

#Preview {
    NavigationStack {
        MySubmissionDetailView(record: MockData.seedPromotionSubmissions[0])
    }
}
