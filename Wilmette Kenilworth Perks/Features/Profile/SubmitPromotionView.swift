import SwiftUI

private enum SubmitPromotionStep: Int, CaseIterable {
    case company = 0
    case offer = 1
    case confirm = 2

    var title: String {
        switch self {
        case .company: "Your company"
        case .offer: "Your offer"
        case .confirm: "Confirm & submit"
        }
    }

    var subtitle: String {
        switch self {
        case .company:
            "Confirm your business and how the chamber can reach you."
        case .offer:
            "Add the title, details, redemption info, and dates for your perk."
        case .confirm:
            "Preview how members will see your promotion, then submit for review."
        }
    }
}

struct SubmitPromotionView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SubmitPromotionViewModel()
    @State private var step: SubmitPromotionStep = .company
    @State private var showSuccessAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                if step != .company {
                    backButton
                }

                WKCCStepProgressBar(
                    labels: ["Company", "Offer", "Confirm"],
                    currentIndex: step.rawValue
                )

                stepHeader

                Group {
                    switch step {
                    case .company:
                        companyStep
                    case .offer:
                        offerStep
                    case .confirm:
                        PromotionPreviewContent(viewModel: viewModel)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: step)

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                footerButtons
            }
            .padding(WKCCSpacing.md)
            .padding(.bottom, WKCCSpacing.lg)
        }
        .wkccPageBackground()
        .navigationTitle("Submit Promotion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Promotion Submitted", isPresented: $showSuccessAlert) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("Thank you! The chamber will review your promotion and follow up if needed.")
        }
        .task {
            viewModel.configure(member: authManager.member)
        }
    }

    // MARK: - Chrome

    private var backButton: some View {
        Button {
            goBack()
        } label: {
            HStack(spacing: WKCCSpacing.xxs) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                Text("Back")
                    .font(WKCCTypography.callout.weight(.semibold))
            }
            .foregroundStyle(WKCCColors.primary)
        }
        .buttonStyle(.plain)
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
            if step == .company {
                HStack(alignment: .center, spacing: WKCCSpacing.sm) {
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
                .padding(.top, WKCCSpacing.xs)
            }
            Text(step.title)
                .font(.system(.title2, design: .default).weight(.bold))
                .foregroundStyle(WKCCColors.textPrimary)

            Text(step.subtitle)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var footerButtons: some View {
        switch step {
        case .company:
            WKCCPrimaryButton(title: "Next") {
                step = .offer
            }
            .disabled(!viewModel.canContinueFromCompany)

        case .offer:
            WKCCPrimaryButton(title: "Next") {
                step = .confirm
            }
            .disabled(!viewModel.canContinueFromOffer)

        case .confirm:
            WKCCPrimaryButton(
                title: "Submit Promotion",
                isLoading: viewModel.isSubmitting
            ) {
                Task {
                    await viewModel.submit()
                    if viewModel.didSubmitSuccessfully {
                        showSuccessAlert = true
                    }
                }
            }
            .disabled(!viewModel.isValid || viewModel.isSubmitting)
        }
    }

    private func goBack() {
        switch step {
        case .company:
            break
        case .offer:
            step = .company
        case .confirm:
            step = .offer
        }
    }

    // MARK: - Steps

    private var companyStep: some View {
        formSection(title: "") {
            readOnlyField("Company Name", value: viewModel.companyName)

            if !viewModel.hasCompanyOnFile {
                Text("Your profile does not have a company on file. Contact the chamber to update your membership before submitting a promotion.")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.warning)
            }

            labeledTextField(
                "Contact Email",
                text: $viewModel.submission.contactEmail,
                keyboard: .emailAddress,
                autocapitalization: .never
            )
            labeledTextField(
                "Contact Phone",
                text: $viewModel.submission.contactPhone,
                keyboard: .phonePad
            )
        }
    }

    private var offerStep: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
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
                DatePicker(
                    "End Date",
                    selection: $viewModel.submission.endDate,
                    in: viewModel.submission.startDate...,
                    displayedComponents: .date
                )
                .tint(WKCCColors.primary)
            }
        }
    }

    // MARK: - Field helpers

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
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
