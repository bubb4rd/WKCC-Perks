import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.selectMainTab) private var selectMainTab
    @Environment(\.showBusinesses) private var showBusinesses
    @State private var viewModel = HomeViewModel()
    @State private var notificationsViewModel = NotificationsViewModel()
    @State private var isShowingNotifications = false
    @State private var selectedHotDeal: HotDeal?

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
            .sheet(item: $selectedHotDeal) { deal in
                HotDealDetailSheet(deal: deal)
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
            HStack(alignment: .center, spacing: WKCCSpacing.sm) {
                WKCCLogoView(style: .mark, maxWidth: 44)

                WKCCSearchField(prompt: "Search perks and businesses", text: $viewModel.searchText)

                if AppConfig.useMockAuth {
                    NotificationBellButton(unreadCount: notificationsViewModel.unreadCount) {
                        isShowingNotifications = true
                    }
                }
            }
            .padding(.horizontal, WKCCSpacing.md)

            categoryChips
        }
        .padding(.top, WKCCSpacing.sm)
        .padding(.bottom, WKCCSpacing.xs)
    }

    /// Tapping a chip opens the Businesses tab filtered to that category.
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WKCCSpacing.xs) {
                ForEach(DealCategory.allCases) { category in
                    CategoryChip(category: category, isSelected: false) {
                        showBusinesses(category)
                    }
                }
            }
            .padding(.horizontal, WKCCSpacing.md)
        }
        .fixedSize(horizontal: false, vertical: true)
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

                if !viewModel.isFiltering, !viewModel.hotDeals.isEmpty {
                    HotDealsSpotlight(
                        deals: viewModel.hotDeals,
                        logoURL: { viewModel.logoURL(for: $0) }
                    ) { selectedHotDeal = $0 }
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
                    LazyVStack(spacing: WKCCSpacing.lg) {
                        ForEach(deals) { deal in
                            DealCard(
                                deal: deal,
                                businessLogoURL: viewModel.logoURL(forBusinessId: deal.businessId)
                            )
                        }
                    }
                }
            }
        } else if viewModel.spotlightDeal == nil, viewModel.hotDeals.isEmpty {
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

/// Rotating spotlight for the chamber's Chambermate "Hot Deals" board. Auto-advances and
/// swipes when there is more than one; a single deal is just a card.
private struct HotDealsSpotlight: View {
    let deals: [HotDeal]
    let logoURL: (HotDeal) -> URL?
    let onSelect: (HotDeal) -> Void

    @State private var selection = 0

    private let pageGap = WKCCSpacing.md

    private var showsPageDots: Bool { deals.count > 1 }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(deals.enumerated()), id: \.element.id) { index, deal in
                Button {
                    onSelect(deal)
                } label: {
                    HotDealCard(deal: deal, imageURL: logoURL(deal), showsPageDots: showsPageDots)
                }
                .buttonStyle(.plain)
                // TabView pages sit flush; half the gap on each side of a page opens it between cards.
                .padding(.horizontal, pageGap / 2)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: showsPageDots ? .automatic : .never))
        .frame(height: 260)
        // Cancels the outer half-gaps so a resting card still spans the content width.
        .padding(.horizontal, -pageGap / 2)
        .onChange(of: deals.count) { _, count in
            selection = min(selection, max(count - 1, 0))
        }
        .task(id: deals.count) {
            guard deals.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                withAnimation { selection = (selection + 1) % deals.count }
            }
        }
    }
}

private struct HotDealCard: View {
    let deal: HotDeal
    let imageURL: URL?
    let showsPageDots: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            PerkCardBackground(imageURL: imageURL)

            VStack(alignment: .leading, spacing: 0) {
                badge
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
                .padding(.horizontal, WKCCSpacing.lg)
                .padding(.top, WKCCSpacing.lg)
                // Keeps the title clear of the page dots.
                .padding(.bottom, showsPageDots ? WKCCSpacing.xl + WKCCSpacing.sm : WKCCSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.xl))
        .wkccCardShadow()
    }

    private var badge: some View {
        HStack(spacing: WKCCSpacing.xxs) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(WKCCColors.accent)
            Text("Hot deal")
                .font(WKCCTypography.captionBold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, WKCCSpacing.sm)
        .padding(.vertical, WKCCSpacing.xxs)
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.sm))
    }
}

/// Full text of a hot deal post. The board is the source of truth, so this is read-only.
private struct HotDealDetailSheet: View {
    let deal: HotDeal
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
                    Text(deal.businessName)
                        .font(WKCCTypography.callout.weight(.semibold))
                        .foregroundStyle(WKCCColors.textSecondary)

                    Text(deal.title)
                        .font(WKCCTypography.title)
                        .foregroundStyle(WKCCColors.textPrimary)

                    if let expiration = deal.expirationDate {
                        Text("Ends \(expiration.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(WKCCTypography.callout.weight(.medium))
                            .foregroundStyle(WKCCColors.accent)
                    }

                    if !deal.body.isEmpty {
                        Text(deal.body)
                            .font(WKCCTypography.body)
                            .foregroundStyle(WKCCColors.textPrimary)
                            .padding(.top, WKCCSpacing.xs)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WKCCSpacing.md)
            }
            .wkccPageBackground()
            .navigationTitle("Hot deal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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

/// Quiet placeholder in the shape of a perk card, shown when the spotlight is the only perk.
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
