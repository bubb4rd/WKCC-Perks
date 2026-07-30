import SwiftUI

struct AdminSubmissionDetailView: View {
    let record: PromotionSubmissionRecord

    var body: some View {
        AdminSubmissionDetailContent(record: record)
    }
}

private struct AdminSubmissionDetailContent: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AdminSubmissionDetailViewModel
    @State private var isEditing = false
    @State private var showSaveSuccess = false
    @State private var showApproveConfirm = false
    @State private var showRejectConfirm = false
    @State private var showReviewedAlert = false
    @State private var reviewedMessage = ""

    init(record: PromotionSubmissionRecord) {
        _viewModel = State(initialValue: AdminSubmissionDetailViewModel(record: record))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                metadataSection(contactPhone: $viewModel.record.submission.contactPhone)

                PromotionSubmissionForm(
                    submission: $viewModel.record.submission,
                    companyName: viewModel.record.companyName,
                    isReadOnly: !viewModel.isPending || !isEditing,
                    showCompanySection: false
                )
                .animation(.easeInOut(duration: 0.25), value: isEditing)

                adminNotesSection

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                if viewModel.isPending {
                    actionButtons
                }
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
        .navigationTitle("Review Submission")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert(reviewedMessage, isPresented: $showReviewedAlert) {
            Button("OK") { dismiss() }
        }
        .confirmationDialog("Approve this promotion?", isPresented: $showApproveConfirm, titleVisibility: .visible) {
            Button("Approve") {
                Task { await approveSubmission() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Approved perks will appear in the Deals tab.")
        }
        .confirmationDialog("Reject this promotion?", isPresented: $showRejectConfirm, titleVisibility: .visible) {
            Button("Reject", role: .destructive) {
                Task { await rejectSubmission() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func metadataSection(contactPhone: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            HStack {
                SubmissionStatusBadge(status: viewModel.record.status)
                Spacer()
            }

            Text(viewModel.record.companyName)
                .font(WKCCTypography.sectionTitle)
                .foregroundStyle(WKCCColors.textPrimary)

            Text(viewModel.record.submitterName)
                .font(WKCCTypography.callout.weight(.medium))
                .foregroundStyle(WKCCColors.textSecondary)

            phoneRow(contactPhone: contactPhone)

            Text(viewModel.record.submittedAt.formatted(date: .abbreviated, time: .shortened))
                .font(WKCCTypography.caption)
                .foregroundStyle(WKCCColors.textSecondary.opacity(0.75))

            if let reviewedAt = viewModel.record.reviewedAt {
                HStack(spacing: WKCCSpacing.xxs) {
                    Image(systemName: viewModel.record.status == .approved ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(WKCCTypography.caption)
                        .foregroundStyle(
                            viewModel.record.status == .approved
                                ? WKCCColors.accent.opacity(0.85)
                                : WKCCColors.error.opacity(0.75)
                        )

                    Text(reviewedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(WKCCTypography.caption)
                        .foregroundStyle(WKCCColors.textSecondary.opacity(0.65))
                }
            }
        }
    }

    @ViewBuilder
    private func phoneRow(contactPhone: Binding<String>) -> some View {
        if viewModel.isPending && isEditing {
            TextField("Phone", text: contactPhone)
                .font(WKCCTypography.callout)
                .keyboardType(.phonePad)
                .foregroundStyle(WKCCColors.textPrimary.opacity(0.9))
        } else if !contactPhone.wrappedValue.isEmpty {
            Text(contactPhone.wrappedValue)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textPrimary.opacity(0.9))
        }
    }

    private var adminNotesSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            Text("Admin Notes")
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            if viewModel.isPending && isEditing {
                TextEditor(text: $viewModel.adminNotes)
                    .font(WKCCTypography.body)
                    .frame(minHeight: 88)
                    .padding(WKCCSpacing.xs)
                    .scrollContentBackground(.hidden)
                    .background(WKCCColors.pageBackground)
                    .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: WKCCRadius.sm)
                            .stroke(WKCCColors.primary.opacity(0.1), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                Text(viewModel.adminNotes.isEmpty ? "No notes recorded." : viewModel.adminNotes)
                    .font(WKCCTypography.body)
                    .foregroundStyle(viewModel.adminNotes.isEmpty ? WKCCColors.textSecondary : WKCCColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(WKCCSpacing.md)
                    .wkccCardStyle()
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: WKCCSpacing.sm) {
            Button {
                showRejectConfirm = true
            } label: {
                Text("Reject")
                    .font(WKCCTypography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, WKCCSpacing.md)
                    .background(WKCCColors.cardBackground)
                    .foregroundStyle(WKCCColors.error)
                    .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: WKCCRadius.md)
                            .stroke(WKCCColors.error.opacity(0.25), lineWidth: 1)
                    )
            }
            .disabled(viewModel.isSaving || viewModel.isReviewing || isEditing)

            Button {
                showApproveConfirm = true
            } label: {
                Group {
                    if viewModel.isReviewing {
                        ProgressView()
                            .tint(WKCCColors.textOnPrimary)
                    } else {
                        Text("Approve")
                            .font(WKCCTypography.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, WKCCSpacing.md)
                .background(WKCCColors.primary)
                .foregroundStyle(WKCCColors.textOnPrimary)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
            }
            .disabled(!viewModel.isValid || viewModel.isSaving || isEditing)
            editSaveButton
        }
    }

    private var editSaveButton: some View {
        Button {
            if isEditing {
                Task { await saveEdits() }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                    isEditing = true
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(editButtonBackground)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(editButtonBorder, lineWidth: isEditing ? 1.5 : 1)
                    )
                    .shadow(color: WKCCColors.primary.opacity(isEditing ? 0.14 : 0.06), radius: isEditing ? 8 : 4, y: 2)

                if viewModel.isSaving {
                    ProgressView()
                        .tint(WKCCColors.primary)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(editButtonForeground)
                        .contentTransition(.symbolEffect(.replace))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(showSaveSuccess ? 1.1 : 1)
        }
        .buttonStyle(AdminIconButtonStyle())
        .disabled(viewModel.isReviewing || (isEditing && (!viewModel.isValid || viewModel.isSaving)))
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isEditing)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: showSaveSuccess)
        .accessibilityLabel(isEditing ? "Save changes" : "Edit submission")
    }

    private var editButtonBackground: Color {
        if showSaveSuccess {
            WKCCColors.accent.opacity(0.2)
        } else if isEditing {
            WKCCColors.accent.opacity(0.14)
        } else {
            WKCCColors.cardBackground
        }
    }

    private var editButtonBorder: Color {
        if showSaveSuccess {
            WKCCColors.accent.opacity(0.55)
        } else if isEditing {
            WKCCColors.accent.opacity(0.45)
        } else {
            WKCCColors.primary.opacity(0.15)
        }
    }

    private var editButtonForeground: Color {
        if showSaveSuccess {
            WKCCColors.accent
        } else if isEditing {
            WKCCColors.accent
        } else {
            WKCCColors.primary
        }
    }

    private func saveEdits() async {
        guard await viewModel.saveChanges() else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            showSaveSuccess = true
            isEditing = false
        }

        try? await Task.sleep(nanoseconds: 650_000_000)

        withAnimation(.easeOut(duration: 0.25)) {
            showSaveSuccess = false
        }
    }

    private func approveSubmission() async {
        guard let adminId = authManager.member?.id else { return }
        if await viewModel.approve(reviewedBy: adminId) {
            reviewedMessage = "Promotion approved and published to Deals."
            showReviewedAlert = true
        }
    }

    private func rejectSubmission() async {
        guard let adminId = authManager.member?.id else { return }
        if await viewModel.reject(reviewedBy: adminId) {
            reviewedMessage = "Promotion rejected."
            showReviewedAlert = true
        }
    }
}

private struct AdminIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        AdminSubmissionDetailView(record: MockData.seedPromotionSubmissions[0])
            .environment(AuthManager())
    }
}
