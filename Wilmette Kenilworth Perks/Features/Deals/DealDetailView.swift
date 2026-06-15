import SwiftUI

struct DealDetailView: View {
    let dealId: String

    @State private var viewModel = DealDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.deal == nil {
                LoadingView(message: "Loading deal...")
            } else if let deal = viewModel.deal {
                dealContent(deal)
            } else {
                EmptyStateView(
                    icon: "tag.slash",
                    title: "Deal Not Found",
                    message: viewModel.errorMessage ?? "This deal may have expired or been removed."
                )
            }
        }
        .navigationTitle("Deal Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WKCCColors.pageBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.load(dealId: dealId)
        }
    }

    private func dealContent(_ deal: DealDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                headerSection(deal)
                descriptionSection(deal)

                if let terms = deal.terms {
                    termsSection(terms)
                }

                redemptionSection(deal)

                NavigationLink {
                    BusinessDetailView(businessId: deal.businessId)
                } label: {
                    HStack {
                        Text("View \(deal.businessName)")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.primary)
                    .padding(WKCCSpacing.md)
                    .wkccCardStyle()
                }
            }
            .padding(WKCCSpacing.md)
        }
        .wkccPageBackground()
    }

    private func headerSection(_ deal: DealDetail) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            HStack {
                if deal.isFeatured {
                    BadgeLabel(text: "Featured", color: WKCCColors.accent)
                }
                if deal.isExpired {
                    BadgeLabel(text: "Expired", color: WKCCColors.error)
                }
            }

            Text(deal.title)
                .font(WKCCTypography.largeTitle)
                .foregroundStyle(WKCCColors.textPrimary)

            NavigationLink {
                BusinessDetailView(businessId: deal.businessId)
            } label: {
                HStack(spacing: WKCCSpacing.xs) {
                    Image(systemName: "building.2")
                    Text(deal.businessName)
                }
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.primary)
            }

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

    private func descriptionSection(_ deal: DealDetail) -> some View {
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

    private func redemptionSection(_ deal: DealDetail) -> some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Label("How to Redeem", systemImage: "checkmark.seal.fill")
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.primary)

            Text(deal.redemptionInstructions)
                .font(WKCCTypography.body)
                .foregroundStyle(WKCCColors.textPrimary)

            if let code = deal.redemptionCode {
                HStack {
                    Text(code)
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundStyle(WKCCColors.primary)

                    Spacer()

                    ShareLink(item: code) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .padding(WKCCSpacing.md)
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
        DealDetailView(dealId: "deal-001")
    }
}
