import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.selectMainTab) private var selectMainTab
    @State private var viewModel = HomeViewModel()
    @State private var notificationsViewModel = NotificationsViewModel()
    @State private var isShowingNotifications = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                Group {
                    if viewModel.isLoading && viewModel.deals.isEmpty {
                        LoadingView(message: "Loading your perks...")
                    } else {
                        scrollContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .refreshable {
                    // Own task so a mid-pull view update can't cancel the request.
                    await Task { await viewModel.load() }.value
                }
            }
            .wkccPageBackground()
            .toolbar(.hidden, for: .navigationBar)
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
                case .submitPromotion:
                    SubmitPromotionView()
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            homeGreeting
                .padding(.horizontal, WKCCSpacing.md)

            WKCCSearchField(prompt: "Search perks and businesses", text: $viewModel.searchText)
                .padding(.horizontal, WKCCSpacing.md)
        }
        .padding(.top, WKCCSpacing.sm)
        .padding(.bottom, WKCCSpacing.xs)
    }

    private var homeGreeting: some View {
        HStack(alignment: .center, spacing: WKCCSpacing.sm) {
            Text("Hi, \(authManager.member?.greetingName ?? "Guest")")
                .font(WKCCTypography.sectionTitle)
                .foregroundStyle(WKCCColors.primary)

            Spacer(minLength: 0)

            if AppConfig.useMockAuth {
                NotificationBellButton(unreadCount: notificationsViewModel.unreadCount) {
                    isShowingNotifications = true
                }
            }
        }
    }

    // MARK: - Content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WKCCSpacing.lg) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                }

                if !viewModel.isFiltering, let spotlight = viewModel.spotlightDeal {
                    NavigationLink(value: spotlight) {
                        SpotlightCard(deal: spotlight, imageURL: viewModel.spotlightImageURL)
                    }
                    .buttonStyle(.plain)
                }

                perksSection

                if !viewModel.isFiltering, !viewModel.previewBusinesses.isEmpty {
                    if viewModel.showsOnlySpotlight {
                        featuredBusinessesGrid
                    } else {
                        businessesStrip
                    }
                }
            }
            .padding(.horizontal, WKCCSpacing.md)
            .padding(.top, WKCCSpacing.xs)
            .padding(.bottom, WKCCSpacing.xl)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    @ViewBuilder
    private var perksSection: some View {
        let deals = viewModel.listedDeals

        if viewModel.isFiltering || !deals.isEmpty || viewModel.showsOnlySpotlight {
            VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
                HStack {
                    Text(perksSectionTitle(count: deals.count))
                        .font(WKCCTypography.headline)
                        .foregroundStyle(WKCCColors.textPrimary)

                    Spacer()

                    NavigationLink(value: HomeDestination.allDeals) {
                        Text("View all")
                            .font(WKCCTypography.captionBold)
                            .foregroundStyle(WKCCColors.accent)
                    }
                }

                if viewModel.showsOnlySpotlight {
                    // The spotlight is the only perk; a quiet empty slot keeps the focus on it.
                    NavigationLink(value: HomeDestination.submitPromotion) {
                        EmptyPerkSlot()
                    }
                    .buttonStyle(.plain)
                } else if deals.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Perks Found",
                        message: "Try a different search."
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, WKCCSpacing.lg)
                } else {
                    LazyVStack(spacing: WKCCSpacing.sm) {
                        ForEach(deals) { deal in
                            NavigationLink(value: deal) {
                                PerkRow(
                                    deal: deal,
                                    logoURL: viewModel.logoURL(forBusinessId: deal.businessId)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        } else if viewModel.spotlightDeal == nil {
            EmptyStateView(
                icon: "tag",
                title: "No Perks Yet",
                message: "Check back soon for member perks."
            )
            .frame(maxWidth: .infinity)
            .padding(.top, WKCCSpacing.xl)
        }
    }

    private func businessesHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            Spacer()

            // Switch tabs rather than push: the Businesses page hides its nav bar,
            // so a pushed copy would have no back button.
            Button {
                selectMainTab(.businesses)
            } label: {
                Text("View all")
                    .font(WKCCTypography.captionBold)
                    .foregroundStyle(WKCCColors.accent)
            }
        }
    }

    /// Shown instead of the logo strip when the spotlight is the only perk, to fill the page.
    private var featuredBusinessesGrid: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            businessesHeader("Featured businesses")

            LazyVGrid(columns: featuredGridColumns, spacing: WKCCSpacing.md) {
                ForEach(viewModel.previewBusinesses.prefix(4)) { business in
                    NavigationLink(value: business) {
                        BusinessGridCard(business: business)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private let featuredGridColumns = [
        GridItem(.flexible(), spacing: WKCCSpacing.md, alignment: .top),
        GridItem(.flexible(), spacing: WKCCSpacing.md, alignment: .top)
    ]

    private var businessesStrip: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            businessesHeader("Businesses")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: WKCCSpacing.md) {
                    ForEach(viewModel.previewBusinesses) { business in
                        NavigationLink(value: business) {
                            BusinessChip(business: business)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func perksSectionTitle(count: Int) -> String {
        guard viewModel.isFiltering else { return "Perks for you" }
        return count == 1 ? "1 perk" : "\(count) perks"
    }

    private var notificationRefreshKey: String {
        "\(authManager.member?.id ?? "guest")-\(authManager.isChamberAdmin)"
    }
}

// MARK: - Navigation

private enum HomeDestination: Hashable {
    case allDeals
    case submitPromotion
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

    private let cardHeight: CGFloat = 260

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
                            .font(.system(.title2, design: .default).weight(.bold))
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

/// Compact perk row: logo thumbnail, title, business, and category / expiry meta line.
private struct PerkRow: View {
    let deal: DealSummary
    let logoURL: URL?

    var body: some View {
        HStack(alignment: .center, spacing: WKCCSpacing.sm) {
            BusinessLogoView(
                url: logoURL,
                size: 64,
                shape: .roundedRect(cornerRadius: WKCCRadius.md)
            )

            VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                Text(deal.title)
                    .font(WKCCTypography.headline)
                    .foregroundStyle(WKCCColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(deal.businessName)
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.textSecondary)
                    .lineLimit(1)

                metaLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WKCCColors.textSecondary)
        }
        .padding(WKCCSpacing.sm)
        .wkccCardStyle()
        .accessibilityElement(children: .combine)
    }

    private var metaLine: some View {
        HStack(spacing: WKCCSpacing.xxs) {
            Image(systemName: deal.category.iconName)
            Text(deal.category.rawValue)
                .lineLimit(1)

            if let expiration = deal.expirationDate {
                Text("·")
                Text("Ends \(expiration.formatted(.dateTime.month(.abbreviated).day()))")
                    .foregroundStyle(deal.isExpiringSoon ? WKCCColors.warning : WKCCColors.textSecondary)
                    .fixedSize()
            }
        }
        .font(WKCCTypography.caption)
        .foregroundStyle(WKCCColors.accent)
    }
}

/// Quiet placeholder in the shape of a `PerkRow`, shown when the spotlight is the only perk.
/// Deliberately low-contrast (no fill, dashed outline) so it doesn't compete with the spotlight.
private struct EmptyPerkSlot: View {
    private let shape = RoundedRectangle(cornerRadius: WKCCRadius.lg)

    var body: some View {
        HStack(alignment: .center, spacing: WKCCSpacing.sm) {
            RoundedRectangle(cornerRadius: WKCCRadius.md)
                .fill(WKCCColors.primary.opacity(0.05))
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "plus")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(WKCCColors.textSecondary)
                }

            VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                Text("Your perk could be here")
                    .font(WKCCTypography.callout.weight(.semibold))
                    .foregroundStyle(WKCCColors.textSecondary)

                Text("Submit a promotion")
                    .font(WKCCTypography.caption.weight(.semibold))
                    .foregroundStyle(WKCCColors.textSecondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(WKCCSpacing.sm)
        .overlay {
            shape.strokeBorder(
                WKCCColors.primary.opacity(0.18),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
            )
        }
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Round logo with the business name underneath, for the Home "Businesses" strip.
private struct BusinessChip: View {
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
