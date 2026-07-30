import SwiftUI

struct EditBusinessProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditBusinessProfileViewModel

    init(companyId: String) {
        _viewModel = State(initialValue: EditBusinessProfileViewModel(companyId: companyId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.businessName.isEmpty {
                LoadingView(message: "Loading business...")
            } else {
                editorForm
            }
        }
        .wkccPageBackground()
        .navigationTitle("Business Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task { await viewModel.save() }
                }
                .font(WKCCTypography.callout.weight(.semibold))
                .foregroundStyle(WKCCColors.accent)
                .disabled(viewModel.isSaving || viewModel.isLoading)
            }
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
        }
        .alert(
            "Couldn't save",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil && !viewModel.isLoading },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var editorForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                if !viewModel.businessName.isEmpty {
                    VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
                        Text("Company")
                            .font(WKCCTypography.caption)
                            .foregroundStyle(WKCCColors.textSecondary)
                        Text(viewModel.businessName)
                            .font(WKCCTypography.headline)
                            .foregroundStyle(WKCCColors.textPrimary)
                        Text("Name is managed by the chamber and can’t be edited here.")
                            .font(WKCCTypography.caption)
                            .foregroundStyle(WKCCColors.textSecondary)
                    }
                }

                formSection {
                    VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
                        fieldLabel("Category")
                        Picker("Category", selection: $viewModel.draft.category) {
                            ForEach(DealCategory.allCases) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(WKCCColors.primary)
                    }

                    labeledTextEditor(
                        "Short about",
                        text: $viewModel.draft.shortDescription,
                        lineLimit: 4
                    )

                    labeledTextField(
                        "Website",
                        text: $viewModel.draft.websiteURLString,
                        keyboard: .URL,
                        autocapitalization: .never
                    )

                    labeledTextField(
                        "Phone",
                        text: $viewModel.draft.phone,
                        keyboard: .phonePad
                    )

                    labeledTextEditor(
                        "Street address",
                        text: $viewModel.draft.address,
                        lineLimit: 3
                    )

                    Toggle(isOn: $viewModel.draft.addressPublic) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show address on public listing")
                                .font(WKCCTypography.callout.weight(.semibold))
                                .foregroundStyle(WKCCColors.textPrimary)
                            Text("When off, members still see Open in Maps if coordinates exist.")
                                .font(WKCCTypography.caption)
                                .foregroundStyle(WKCCColors.textSecondary)
                        }
                    }
                    .tint(WKCCColors.accent)
                }

                Text("Update your business photo from the Profile avatar.")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)
            }
            .padding(WKCCSpacing.md)
            .padding(.bottom, WKCCSpacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func formSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            content()
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wkccCardStyle()
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(WKCCTypography.caption)
            .foregroundStyle(WKCCColors.textSecondary)
    }

    private func labeledTextField(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .sentences
    ) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
            fieldLabel(title)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(keyboard == .URL || keyboard == .emailAddress)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textPrimary)
                .padding(WKCCSpacing.sm)
                .background(WKCCColors.pageBackground)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.sm, style: .continuous))
        }
    }

    private func labeledTextEditor(
        _ title: String,
        text: Binding<String>,
        lineLimit: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
            fieldLabel(title)
            TextField(title, text: text, axis: .vertical)
                .lineLimit(lineLimit...lineLimit + 2)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textPrimary)
                .padding(WKCCSpacing.sm)
                .background(WKCCColors.pageBackground)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.sm, style: .continuous))
        }
    }
}

#Preview {
    NavigationStack {
        EditBusinessProfileView(companyId: "1")
    }
}
