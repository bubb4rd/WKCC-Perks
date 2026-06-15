import SwiftUI

struct SubmitPromotionView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SubmitPromotionViewModel()
    @State private var showPreview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                introSection

                formSection(title: "Company") {
                    readOnlyField("Company Name", value: viewModel.companyName)

                    if !viewModel.hasCompanyOnFile {
                        Text("Your profile does not have a company on file. Contact the chamber to update your membership before submitting a promotion.")
                            .font(WKCCTypography.caption)
                            .foregroundStyle(WKCCColors.warning)
                    }

                    labeledTextField("Contact Email", text: $viewModel.submission.contactEmail, keyboard: .emailAddress, autocapitalization: .never)
                    labeledTextField("Contact Phone", text: $viewModel.submission.contactPhone, keyboard: .phonePad)
                }

                formSection(title: "Promotion Details") {
                    labeledTextField("Promotion Title", text: $viewModel.submission.title)

                    VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
                        fieldLabel("Category")
                        Picker("Category", selection: $viewModel.submission.category) {
                            ForEach(DealCategory.allCases) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(WKCCColors.primary)
                    }

                    labeledTextEditor("Short Summary", text: $viewModel.submission.shortDescription, lineLimit: 3)
                    labeledTextEditor("Full Description", text: $viewModel.submission.fullDescription, lineLimit: 5)
                    labeledTextEditor("Terms & Exclusions (optional)", text: $viewModel.submission.terms, lineLimit: 3)
                    labeledTextEditor("Redemption Instructions", text: $viewModel.submission.redemptionInstructions, lineLimit: 4)

                    VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
                        fieldLabel("Redemption Code Type")
                        Picker("Redemption Code Type", selection: $viewModel.submission.redemptionCodeType) {
                            ForEach(RedemptionCodeType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(WKCCColors.primary)
                    }

                    if viewModel.submission.redemptionCodeType.requiresCodeValue {
                        labeledTextField(
                            viewModel.submission.redemptionCodeType.codeFieldLabel,
                            text: $viewModel.submission.redemptionCode,
                            placeholder: viewModel.submission.redemptionCodeType.codeFieldPlaceholder,
                            autocapitalization: .never
                        )
                    }
                }

                formSection(title: "Dates") {
                    DatePicker("Start Date", selection: $viewModel.submission.startDate, displayedComponents: .date)
                        .tint(WKCCColors.primary)
                    DatePicker("End Date", selection: $viewModel.submission.endDate, in: viewModel.submission.startDate..., displayedComponents: .date)
                        .tint(WKCCColors.primary)
                }

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                WKCCPrimaryButton(title: "Preview Promotion") {
                    showPreview = true
                }
                .disabled(!viewModel.isValid)
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
        .navigationTitle("Submit Promotion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(isPresented: $showPreview) {
            PromotionPreviewView(viewModel: viewModel) {
                dismiss()
            }
        }
        .task {
            viewModel.configure(member: authManager.member)
        }
    }

    private var introSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [WKCCColors.primary, WKCCColors.primary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "megaphone.fill")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.18))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(WKCCSpacing.lg)
            }
            .frame(height: 112)

            VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
                Text("New Member Promotion")
                    .font(.system(.title2, design: .default).weight(.bold))
                    .foregroundStyle(WKCCColors.textPrimary)

                Text("Submit a perk for your company. Required fields are marked in each section below.")
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: WKCCSpacing.sm) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(WKCCColors.accent)

                    Text("Submissions are reviewed by the chamber before appearing in the app.")
                        .font(.system(.callout, design: .default).weight(.semibold).italic())
                        .foregroundStyle(WKCCColors.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(WKCCSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WKCCColors.accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.sm))
            }
            .padding(WKCCSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WKCCColors.cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
        .wkccCardShadow()
    }

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            Text(title)
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            VStack(alignment: .leading, spacing: WKCCSpacing.md) {
                content()
            }
            .padding(WKCCSpacing.md)
            .wkccCardStyle()
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(WKCCTypography.captionBold)
            .foregroundStyle(WKCCColors.textSecondary)
    }

    private func readOnlyField(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
            fieldLabel(title)
            Text(value.isEmpty ? "No company on file" : value)
                .font(WKCCTypography.body)
                .foregroundStyle(value.isEmpty ? WKCCColors.textSecondary : WKCCColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WKCCSpacing.sm)
                .background(WKCCColors.pageBackground.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: WKCCRadius.sm)
                        .stroke(WKCCColors.primary.opacity(0.1), lineWidth: 1)
                )
        }
    }

    private func labeledTextField(
        _ title: String,
        text: Binding<String>,
        placeholder: String? = nil,
        keyboard: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .sentences
    ) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
            fieldLabel(title)
            TextField(placeholder ?? title, text: text)
                .font(WKCCTypography.body)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalization)
                .padding(WKCCSpacing.sm)
                .background(WKCCColors.pageBackground)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.sm))
        }
    }

    private func labeledTextEditor(_ title: String, text: Binding<String>, lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
            fieldLabel(title)
            TextEditor(text: text)
                .font(WKCCTypography.body)
                .frame(minHeight: CGFloat(lineLimit) * 22)
                .padding(WKCCSpacing.xs)
                .scrollContentBackground(.hidden)
                .background(WKCCColors.pageBackground)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.sm))
        }
    }
}

#Preview {
    NavigationStack {
        SubmitPromotionView()
            .environment(AuthManager())
    }
}
