import SwiftUI

struct AdminPerkEditorView: View {
    let mode: AdminPerkEditorViewModel.Mode

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AdminPerkEditorViewModel
    @State private var showSavedAlert = false

    init(mode: AdminPerkEditorViewModel.Mode) {
        self.mode = mode
        _viewModel = State(initialValue: AdminPerkEditorViewModel(mode: mode))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            if viewModel.isLoading {
                LoadingView(message: "Loading...")
            } else {
                editorForm
            }
        }
        .wkccPageBackground()
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task { await save() }
                }
                .font(WKCCTypography.callout.weight(.semibold))
                .foregroundStyle(WKCCColors.accent)
                .disabled(!viewModel.isValid || viewModel.isSaving)
            }
        }
        .task {
            await viewModel.load()
        }
        .alert("Perk saved", isPresented: $showSavedAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("This perk is now visible in the Deals tab.")
        }
    }

    private var editorForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                businessSection

                PromotionSubmissionForm(
                    submission: $viewModel.submission,
                    companyName: viewModel.selectedBusinessName,
                    isReadOnly: false,
                    showCompanySection: false
                )

                if viewModel.isSaving {
                    ProgressView("Saving perk...")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(WKCCSpacing.md)
        }
    }

    private var businessSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("Participating Business")
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            if viewModel.businesses.isEmpty {
                Text("No businesses available.")
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.textSecondary)
            } else {
                Picker("Business", selection: $viewModel.selectedBusinessId) {
                    ForEach(viewModel.businesses) { business in
                        Text(business.name).tag(business.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(WKCCColors.primary)
            }
        }
        .padding(WKCCSpacing.md)
        .wkccCardStyle()
    }

    private func save() async {
        guard await viewModel.save() else { return }
        showSavedAlert = true
    }
}

#Preview("Create") {
    NavigationStack {
        AdminPerkEditorView(mode: .create)
    }
}

#Preview("Edit") {
    NavigationStack {
        AdminPerkEditorView(mode: .edit(dealId: MockData.dealSummaries[0].id))
    }
}
