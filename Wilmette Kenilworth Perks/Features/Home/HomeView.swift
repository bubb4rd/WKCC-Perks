import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = HomeViewModel()
    @State private var notificationsViewModel = NotificationsViewModel()
    @State private var isShowingNotifications = false

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
            .onReceive(NotificationCenter.default.publisher(for: .businessLogoDidChange)) { _ in
                Task { await viewModel.load() }
            }
            .task(id: notificationRefreshKey) {
                guard AppConfig.useMockAuth else { return }
                await notificationsViewModel.load(
                    member: authManager.member,
                    isAdmin: authManager.isChamberAdmin
                )
            }
            .sheet(isPresented: $isShowingNotifications) {
                NotificationsView(
                    viewModel: notificationsViewModel,
                    member: authManager.member,
                    isAdmin: authManager.isChamberAdmin
                )
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
                }
            }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }
                homeGreeting
                if let spotlight = viewModel.spotlightDeal {
                    spotlightSection(spotlight, imageURL: viewModel.spotlightImageURL)
                }

                quickAccessGrid

                if !viewModel.previewBusinesses.isEmpty {
                    partnerStrip
                }
            }
            .padding(.horizontal, WKCCSpacing.md)
            .padding(.top, WKCCSpacing.sm)
            .padding(.bottom, WKCCSpacing.xl)
        }
        .wkccPageBackground()
    }

    private var notificationRefreshKey: String {
        "\(authManager.member?.id ?? "guest")-\(authManager.isChamberAdmin)"
    }

    private var homeGreeting: some View {
        HStack(alignment: .center, spacing: WKCCSpacing.sm) {
            VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                Text("Hi, \(authManager.member?.greetingName ?? "Guest")")
                    .font(WKCCTypography.sectionTitle)
                    .foregroundStyle(WKCCColors.primary)
            }

            Spacer(minLength: 0)

            if AppConfig.useMockAuth {
                NotificationBellButton(unreadCount: notificationsViewModel.unreadCount) {
                    isShowingNotifications = true
                }
            }
        }
    }

    private func spotlightSection(_ deal: DealSummary, imageURL: URL?) -> some View {
        NavigationLink(value: deal) {
            SpotlightCard(deal: deal, imageURL: imageURL)
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
                Image("WKCCLogo")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .frame(minHeight: HomeBentoMetrics.tileMinHeight)
                    .padding(HomeBentoMetrics.tilePadding)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Member Card")
            }
            .allowsHitTesting(false)
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

}

private enum HomeBentoMetrics {
    static let tileMinHeight: CGFloat = 128
    static let tilePadding: CGFloat = WKCCSpacing.md
}

// MARK: - Navigation

private enum HomeDestination: Hashable {
    case allDeals
    case expiringDeals
    case businesses
    case memberCard
}

// MARK: - Components

private struct NotificationBellButton: View {
    let unreadCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.title3)
                    .foregroundStyle(WKCCColors.primary)
                    .frame(width: 40, height: 40)
                    .background(WKCCColors.cardBackground)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(WKCCColors.primary.opacity(0.08), lineWidth: 1)
                    )

                if unreadCount > 0 {
                    Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WKCCColors.textOnPrimary)
                        .padding(.horizontal, unreadCount > 9 ? 4 : 5)
                        .padding(.vertical, 2)
                        .background(WKCCColors.error)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications")
        .accessibilityValue(unreadCount > 0 ? "\(unreadCount) unread" : "No unread notifications")
    }
}

private struct SpotlightCard: View {
    let deal: DealSummary
    let imageURL: URL?

    private let cardHeight: CGFloat = 220

    var body: some View {
        ZStack(alignment: .topLeading) {
            PerkCardBackground(imageURL: imageURL)

            VStack(alignment: .leading, spacing: 0) {
                spotlightBadge
                    .padding(WKCCSpacing.lg)

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                        Text(deal.title)
                            .font(.system(.title3, design: .default).weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(deal.businessName)
                            .font(WKCCTypography.callout)
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)

                        if let expiration = deal.expirationDate {
                            Text("Ends \(expiration.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(WKCCTypography.callout.weight(.medium))
                                .foregroundStyle(WKCCColors.accent)
                        }
                    }

                    Spacer(minLength: WKCCSpacing.sm)

                    HStack(spacing: WKCCSpacing.xxs) {
                        Text("View")
                            .font(WKCCTypography.callout.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                }
                .padding(WKCCSpacing.lg)
            }
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl))
        .wkccCardShadow()
    }

    private var spotlightBadge: some View {
        HStack(spacing: WKCCSpacing.xxs) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(WKCCColors.accent)
            Text("Spotlight")
                .font(WKCCTypography.captionBold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, WKCCSpacing.sm)
        .padding(.vertical, WKCCSpacing.xxs)
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.sm))
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
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(WKCCColors.textPrimary)
            }

            Text(label)
                .font(WKCCTypography.captionBold)
                .foregroundStyle(WKCCColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: HomeBentoMetrics.tileMinHeight, alignment: .leading)
        .padding(HomeBentoMetrics.tilePadding)
        .background(WKCCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.lg))
    }
}

private struct PartnerChip: View {
    let business: ChamberBusiness

    var body: some View {
        VStack(spacing: WKCCSpacing.xs) {
            BusinessLogoView(url: business.logoURL, size: 56, shape: .circle)

            Text(business.name)
                .font(WKCCTypography.caption)
                .foregroundStyle(WKCCColors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
    }
}

#Preview {
    HomeView()
        .environment(AuthManager())
}
