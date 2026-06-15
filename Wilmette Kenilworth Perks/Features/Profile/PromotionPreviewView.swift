import SwiftUI

struct PromotionPreviewView: View {
    @Bindable var viewModel: SubmitPromotionViewModel
    let onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showSuccessAlert = false

    private var dealSummary: DealSummary { viewModel.previewDealSummary }
    private var dealDetail: DealDetail { viewModel.previewDealDetail }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                previewBanner

                previewSection(title: "Deals List Card") {
                    DealCard(deal: dealSummary)
                }

                previewSection(title: "Deal Detail View") {
                    PromotionDetailPreview(deal: dealDetail, codeType: viewModel.submission.redemptionCodeType)
                }

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                VStack(spacing: WKCCSpacing.sm) {
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
                    .disabled(viewModel.isSubmitting)

                    WKCCSecondaryButton(title: "Edit Promotion") {
                        dismiss()
                    }
                }
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Promotion Submitted", isPresented: $showSuccessAlert) {
            Button("Done") {
                onSubmitted()
            }
        } message: {
            Text("Thank you! The chamber will review your promotion and follow up if needed.")
        }
    }

    private var previewBanner: some View {
        HStack(alignment: .top, spacing: WKCCSpacing.sm) {
            Image(systemName: "eye.fill")
                .foregroundStyle(WKCCColors.primary)

            Text("This is how your promotion will appear to members. Review the card and detail view, then submit or go back to edit.")
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textPrimary)
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WKCCColors.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
    }

    private func previewSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text(title.uppercased())
                .font(WKCCTypography.brandCaps)
                .foregroundStyle(WKCCColors.primary)
                .tracking(0.5)

            content()
        }
    }
}

private struct PromotionDetailPreview: View {
    let deal: DealDetail
    let codeType: RedemptionCodeType

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
            headerSection
            descriptionSection

            if let terms = deal.terms {
                termsSection(terms)
            }

            redemptionSection
        }
        .padding(WKCCSpacing.md)
        .wkccCardStyle()
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            BadgeLabel(text: "Preview", color: WKCCColors.primary)

            Text(deal.title)
                .font(WKCCTypography.largeTitle)
                .foregroundStyle(WKCCColors.textPrimary)

            HStack(spacing: WKCCSpacing.xs) {
                Image(systemName: "building.2")
                Text(deal.businessName)
            }
            .font(WKCCTypography.callout)
            .foregroundStyle(WKCCColors.primary)

            HStack(spacing: WKCCSpacing.md) {
                Label(deal.category.rawValue, systemImage: deal.category.iconName)
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)

                if let expiration = deal.expirationDate {
                    Label(expiration.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
                        .font(WKCCTypography.caption)
                        .foregroundStyle(WKCCColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("About This Perk")
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            Text(deal.description)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func termsSection(_ terms: String) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("Terms & Exclusions")
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            Text(terms)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var redemptionSection: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Label("How to Redeem", systemImage: "checkmark.seal.fill")
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.primary)

            Text(deal.redemptionInstructions)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textPrimary)

            if codeType == .promoCode, let code = deal.redemptionCode {
                HStack {
                    Text(code)
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundStyle(WKCCColors.primary)

                    Spacer()

                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(WKCCColors.textSecondary)
                }
                .padding(WKCCSpacing.md)
                .background(WKCCColors.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
            } else if codeType == .barcode || codeType == .qrCode, let code = deal.redemptionCode {
                VStack(alignment: .leading, spacing: WKCCSpacing.xs) {
                    Text(codeType.rawValue)
                        .font(WKCCTypography.captionBold)
                        .foregroundStyle(WKCCColors.textSecondary)

                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(WKCCColors.primary)
                }
                .padding(WKCCSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WKCCColors.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
            }
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WKCCColors.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: WKCCRadius.lg)
                .stroke(WKCCColors.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        PromotionPreviewView(viewModel: SubmitPromotionViewModel()) {}
    }
}
