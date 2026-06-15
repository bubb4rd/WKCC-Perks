import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = HomeViewModel()

    private let bentoColumns = [
        GridItem(.flexible(), spacing: WKCCSpacing.sm),
        GridItem(.flexible(), spacing: WKCCSpacing.sm)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.deals.isEmpty {
                    LoadingView(message: "Loading your perks...")
                } else {
                    scrollContent
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await viewModel.load()
            }
            .task {
                await viewModel.load()
            }
            .navigationDestination(for: DealSummary.self) { deal in
                DealDetailView(dealId: deal.id)
            }
            .navigationDestination(for: ChamberBusiness.self) { business in
                BusinessDetailView(businessId: business.id)
            }
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .allDeals:
                    DealsListView()
                case .expiringDeals:
                    DealsListView(initialFilter: .expiringSoon)
                case .businesses:
                    BusinessesListView()
                case .memberCard:
                    MemberCardView()
                case .category(let category):
                    DealsListView(initialCategory: category)
                }
            }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                welcomeBanner

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                if let spotlight = viewModel.spotlightDeal {
                    spotlightSection(spotlight)
                }

                quickAccessGrid

                if !viewModel.previewBusinesses.isEmpty {
                    partnerStrip
                }

                categoryGrid
            }
            .padding(.horizontal, WKCCSpacing.md)
            .padding(.bottom, WKCCSpacing.xl)
        }
        .wkccPageBackground()
    }

    private var welcomeBanner: some View {
        HStack(alignment: .center, spacing: WKCCSpacing.md) {
            WKCCLogoView(style: .mark, maxWidth: 52)

            VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                Text(authManager.member?.greetingName ?? "Member")
                    .font(.system(.title2, design: .default).weight(.bold))
                    .foregroundStyle(WKCCColors.textPrimary)

                Text("WKCC Perks")
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.textSecondary)
            }

            Spacer()

            if let member = authManager.member {
                MembershipTierBadge(tier: member.membershipTier, style: .compact)
            }
        }
        .padding(WKCCSpacing.md)
        .background(
            LinearGradient(
                colors: [
                    WKCCColors.primary.opacity(0.06),
                    WKCCColors.accent.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
        .padding(.top, WKCCSpacing.sm)
    }

    private func spotlightSection(_ deal: DealSummary) -> some View {
        NavigationLink(value: deal) {
            SpotlightCard(deal: deal)
        }
        .buttonStyle(.plain)
    }

    private var quickAccessGrid: some View {
        LazyVGrid(columns: bentoColumns, spacing: WKCCSpacing.sm) {
            NavigationLink(value: HomeDestination.allDeals) {
                BentoTile(
                    icon: "tag.fill",
                    value: "\(viewModel.activeDealCount)",
                    label: "Perks",
                    tint: WKCCColors.primary
                )
            }

            NavigationLink(value: HomeDestination.expiringDeals) {
                BentoTile(
                    icon: "clock.fill",
                    value: "\(viewModel.expiringDealCount)",
                    label: "Ending Soon",
                    tint: viewModel.expiringDealCount > 0 ? WKCCColors.warning : WKCCColors.textSecondary
                )
            }

            NavigationLink(value: HomeDestination.businesses) {
                BentoTile(
                    icon: "building.2.fill",
                    value: "\(viewModel.businessCount)",
                    label: "Partners",
                    tint: WKCCColors.primary
                )
            }

            NavigationLink(value: HomeDestination.memberCard) {
                BentoTile(
                    icon: "creditcard.fill",
                    value: nil,
                    label: "Member Card",
                    tint: WKCCColors.accent
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var partnerStrip: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            HStack {
                Text("Partners")
                    .font(WKCCTypography.headline)
                    .foregroundStyle(WKCCColors.textPrimary)

                Spacer()

                NavigationLink(value: HomeDestination.businesses) {
                    Text("View all")
                        .font(WKCCTypography.captionBold)
                        .foregroundStyle(WKCCColors.accent)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WKCCSpacing.md) {
                    ForEach(viewModel.previewBusinesses) { business in
                        NavigationLink(value: business) {
                            PartnerChip(business: business)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Text("Categories")
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            LazyVGrid(columns: bentoColumns, spacing: WKCCSpacing.sm) {
                ForEach(DealCategory.allCases) { category in
                    NavigationLink(value: HomeDestination.category(category)) {
                        CategoryTile(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

}

// MARK: - Navigation

private enum HomeDestination: Hashable {
    case allDeals
    case expiringDeals
    case businesses
    case memberCard
    case category(DealCategory)
}

// MARK: - Components

private struct SpotlightCard: View {
    let deal: DealSummary

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [WKCCColors.primary, WKCCColors.primary.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: deal.category.iconName)
                .font(.system(size: 88, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.12))
                .offset(x: 12, y: -8)

            VStack(alignment: .leading, spacing: WKCCSpacing.md) {
                HStack(spacing: WKCCSpacing.xs) {
                    HStack(spacing: WKCCSpacing.xxs) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("Spotlight")
                            .font(WKCCTypography.captionBold)
                    }
                    .foregroundStyle(WKCCColors.primary)
                    .padding(.horizontal, WKCCSpacing.sm)
                    .padding(.vertical, WKCCSpacing.xxs)
                    .background(WKCCColors.accent)
                    .clipShape(Capsule())

                    Spacer()
                }

                Text(deal.title)
                    .font(.system(.title2, design: .default).weight(.bold))
                    .foregroundStyle(WKCCColors.textOnPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                        Text(deal.businessName)
                            .font(WKCCTypography.callout)
                            .foregroundStyle(WKCCColors.textOnPrimary.opacity(0.85))

                        if let expiration = deal.expirationDate {
                            Text("Ends \(expiration.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(WKCCTypography.captionBold)
                                .foregroundStyle(WKCCColors.accent)
                        }
                    }

                    Spacer()

                    HStack(spacing: WKCCSpacing.xxs) {
                        Text("View")
                            .font(WKCCTypography.captionBold)
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(WKCCColors.textOnPrimary.opacity(0.9))
                }
            }
            .padding(WKCCSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: WKCCRadius.xl)
                .stroke(WKCCColors.accent.opacity(0.45), lineWidth: 1.5)
        )
        .shadow(color: WKCCColors.primary.opacity(0.28), radius: 16, x: 0, y: 8)
    }
}

private struct BentoTile: View {
    let icon: String
    let value: String?
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)

            Spacer(minLength: 0)

            if let value {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(WKCCColors.textPrimary)
            }

            Text(label)
                .font(WKCCTypography.captionBold)
                .foregroundStyle(WKCCColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .padding(WKCCSpacing.md)
        .background(WKCCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
    }
}

private struct PartnerChip: View {
    let business: ChamberBusiness

    var body: some View {
        VStack(spacing: WKCCSpacing.xs) {
            ZStack {
                Circle()
                    .fill(WKCCColors.primary.opacity(0.1))
                    .frame(width: 56, height: 56)

                Text(business.name.prefix(1).uppercased())
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WKCCColors.primary)
            }

            Text(business.name)
                .font(WKCCTypography.caption)
                .foregroundStyle(WKCCColors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
    }
}

private struct CategoryTile: View {
    let category: DealCategory

    var body: some View {
        HStack(spacing: WKCCSpacing.sm) {
            Image(systemName: category.iconName)
                .font(.body)
                .foregroundStyle(WKCCColors.primary)
                .frame(width: 24)

            Text(category.rawValue)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity)
        .background(WKCCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
    }
}

#Preview {
    HomeView()
        .environment(AuthManager())
}
