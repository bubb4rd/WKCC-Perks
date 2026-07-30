import SwiftUI

struct PromotionSubmissionForm: View {
    @Binding var submission: PromotionSubmission
    let companyName: String
    var isReadOnly: Bool = false
    var showCompanySection: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
            if showCompanySection {
                formSection(title: "Company") {
                    readOnlyField("Company Name", value: companyName)

                    if isReadOnly {
                        readOnlyField("Contact Email", value: submission.contactEmail)
                        if !submission.contactPhone.isEmpty {
                            readOnlyField("Contact Phone", value: submission.contactPhone)
                        }
                    } else {
                        labeledTextField("Contact Email", text: $submission.contactEmail, keyboard: .emailAddress, autocapitalization: .never)
                        labeledTextField("Contact Phone", text: $submission.contactPhone, keyboard: .phonePad)
                    }
                }
            }

            formSection(title: "Promotion Details") {
                if isReadOnly {
                    readOnlyField("Promotion Title", value: submission.title)
                    readOnlyField("Category", value: submission.category.rawValue)
                    readOnlyField("Short Summary", value: submission.shortDescription)
                    readOnlyField("Full Description", value: submission.fullDescription)
                    if !submission.terms.isEmpty {
                        readOnlyField("Terms & Exclusions", value: submission.terms)
                    }
                    readOnlyField("Redemption Instructions", value: submission.redemptionInstructions)
                    readOnlyField("Redemption Code Type", value: submission.redemptionCodeType.rawValue)
                    if submission.redemptionCodeType.requiresCodeValue {
                        readOnlyField(submission.redemptionCodeType.codeFieldLabel, value: submission.redemptionCode)
                    }
                } else {
                    labeledTextField("Promotion Title", text: $submission.title)

                    VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
                        fieldLabel("Category")
                        Picker("Category", selection: $submission.category) {
                            ForEach(DealCategory.allCases) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(WKCCColors.primary)
                    }

                    labeledTextEditor("Short Summary", text: $submission.shortDescription, lineLimit: 3)
                    labeledTextEditor("Full Description", text: $submission.fullDescription, lineLimit: 5)
                    labeledTextEditor("Terms & Exclusions (optional)", text: $submission.terms, lineLimit: 3)
                    labeledTextEditor("Redemption Instructions", text: $submission.redemptionInstructions, lineLimit: 4)

                    VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
                        fieldLabel("Redemption Code Type")
                        Picker("Redemption Code Type", selection: $submission.redemptionCodeType) {
                            ForEach(RedemptionCodeType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(WKCCColors.primary)
                    }

                    if submission.redemptionCodeType.requiresCodeValue {
                        labeledTextField(
                            submission.redemptionCodeType.codeFieldLabel,
                            text: $submission.redemptionCode,
                            placeholder: submission.redemptionCodeType.codeFieldPlaceholder,
                            autocapitalization: .never
                        )
                    }
                }
            }

            formSection(title: "Dates") {
                if isReadOnly {
                    readOnlyField("Start Date", value: submission.startDate.formatted(date: .abbreviated, time: .omitted))
                    readOnlyField("End Date", value: submission.endDate.formatted(date: .abbreviated, time: .omitted))
                } else {
                    DatePicker("Start Date", selection: $submission.startDate, displayedComponents: .date)
                        .tint(WKCCColors.primary)
                    DatePicker("End Date", selection: $submission.endDate, in: submission.startDate..., displayedComponents: .date)
                        .tint(WKCCColors.primary)
                }
            }
        }
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
            Text(value.isEmpty ? "—" : value)
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
