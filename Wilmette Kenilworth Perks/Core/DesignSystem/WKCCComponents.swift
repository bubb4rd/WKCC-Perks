import SwiftUI

struct WKCCPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WKCCSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(WKCCTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, WKCCSpacing.md)
            .background(WKCCColors.primary)
            .foregroundStyle(WKCCColors.textOnPrimary)
            .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
        }
        .disabled(isLoading)
    }
}

struct WKCCSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WKCCTypography.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, WKCCSpacing.md)
                .background(WKCCColors.cardBackground)
                .foregroundStyle(WKCCColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: WKCCRadius.md)
                        .stroke(WKCCColors.primary.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

struct PerkCardBackground: View {
    let imageURL: URL?
    var showsGradient: Bool = true

    var body: some View {
        ZStack {
            cardImage

            if showsGradient {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.2),
                        Color.black.opacity(0.35),
                        Color.black.opacity(0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    @ViewBuilder
    private var cardImage: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                case .empty:
                    Color(white: 0.9)
                case .failure:
                    placeholderImage
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        Image("PerkPlaceholder")
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
    }
}

struct DealCard: View {
    let deal: DealSummary
    var businessLogoURL: URL? = nil

    private let logoSize: CGFloat = 92
    /// How far the logo hangs past the white card on the top and leading edges.
    private let logoOutset: CGFloat = 14

    @State private var redemptionDeal: DealDetail?
    @State private var didCopyCode = false
    @State private var isLoadingRedeem = false

    /// Logo footprint that sits inside the padded card content.
    private var logoContentSpan: CGFloat {
        max(0, logoSize - logoOutset - WKCCSpacing.md)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.md) {
            HStack(alignment: .center, spacing: WKCCSpacing.sm) {
                Color.clear
                    .frame(width: logoContentSpan, height: logoContentSpan)

                Text(deal.businessName)
                    .font(WKCCTypography.title)
                    .foregroundStyle(WKCCColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(deal.shortDescription.isEmpty ? deal.title : deal.shortDescription)
                .font(.system(.title3, design: .default))
                .foregroundStyle(Color.black)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            footerRow
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wkccCardStyle()
        .padding(.top, logoOutset)
        .padding(.leading, logoOutset)
        .overlay(alignment: .topLeading) {
            companyLogo
        }
        .sheet(item: $redemptionDeal) { detail in
            DealRedemptionSheet(deal: detail, didCopyCode: $didCopyCode)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var footerRow: some View {
        HStack(alignment: .center, spacing: WKCCSpacing.sm) {
            expirationLabel

            Spacer(minLength: WKCCSpacing.xs)

            HStack(spacing: WKCCSpacing.xs) {
                NavigationLink(value: deal) {
                    dealCTALabel(
                        title: "View",
                        systemImage: "eye",
                        style: .secondary
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await openRedemption() }
                } label: {
                    dealCTALabel(
                        title: "Redeem",
                        systemImage: "qrcode",
                        style: .primary
                    )
                }
                .buttonStyle(.plain)
                .disabled(deal.isExpired || isLoadingRedeem)
                .opacity(deal.isExpired ? 0.45 : 1)
            }
        }
    }

    private enum DealCTASStyle {
        case secondary
        case primary
    }

    private func dealCTALabel(title: String, systemImage: String, style: DealCTASStyle) -> some View {
        HStack(spacing: WKCCSpacing.xxs) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(WKCCTypography.callout.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(style == .secondary ? WKCCColors.primary : WKCCColors.textOnPrimary)
        .padding(.horizontal, WKCCSpacing.sm)
        .padding(.vertical, WKCCSpacing.xs)
        .background(style == .secondary ? WKCCColors.cardBackground : WKCCColors.primary)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.sm, style: .continuous))
    }

    private func openRedemption() async {
        guard !deal.isExpired, !isLoadingRedeem else { return }
        isLoadingRedeem = true
        defer { isLoadingRedeem = false }

        do {
            let detail = try await AppDependencies.shared.dealsService.fetchDeal(id: deal.id)
            didCopyCode = false
            redemptionDeal = detail
        } catch {
            // Keep card quiet on failure; detail screen remains available via View.
        }
    }

    private var companyLogo: some View {
        BusinessLogoView(
            url: businessLogoURL,
            size: logoSize,
            shape: .roundedRect(cornerRadius: WKCCRadius.md)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var expirationLabel: some View {
        if let expiration = deal.expirationDate {
            Label {
                Text(expiration, format: .dateTime.month(.abbreviated).day())
            } icon: {
                Image(systemName: "clock")
            }
            .font(WKCCTypography.body.weight(.medium))
            .foregroundStyle(deal.isExpiringSoon ? WKCCColors.warning : Color.black)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
    }
}

struct BusinessCard: View {
    let business: ChamberBusiness

    var body: some View {
        HStack(spacing: WKCCSpacing.md) {
            BusinessLogoView(url: business.logoURL, size: 56, shape: .roundedRect())

            VStack(alignment: .leading, spacing: WKCCSpacing.xxs) {
                Text(business.name)
                    .font(WKCCTypography.headline)
                    .foregroundStyle(WKCCColors.textPrimary)

                Text(business.category.rawValue)
                    .font(WKCCTypography.caption)
                    .foregroundStyle(WKCCColors.accent)

                if business.activeDealCount > 0 {
                    Text("\(business.activeDealCount) active perk\(business.activeDealCount == 1 ? "" : "s")")
                        .font(WKCCTypography.captionBold)
                        .foregroundStyle(WKCCColors.primary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(WKCCColors.textSecondary)
        }
        .padding(WKCCSpacing.md)
        .wkccCardStyle()
    }
}

enum BadgeSurface {
    case light
    case dark
}

struct BadgeLabel: View {
    let text: String
    let color: Color
    var surface: BadgeSurface = .light

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, WKCCSpacing.xs)
            .padding(.vertical, WKCCSpacing.xxs)
            .background(backgroundColor)
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch surface {
        case .light:
            return color.opacity(0.15)
        case .dark:
            return Color.black.opacity(0.45)
        }
    }
}

struct DealStatusChips: View {
    let isExpiringSoon: Bool
    let isExpired: Bool
    let membersOnly: Bool
    var surface: BadgeSurface = .light

    var body: some View {
        FlowLayout(spacing: WKCCSpacing.xs) {
            if isExpiringSoon && !isExpired {
                BadgeLabel(text: "Ending Soon", color: WKCCColors.warning, surface: surface)
            }
            if isExpired {
                BadgeLabel(text: "Expired", color: WKCCColors.error, surface: surface)
            }
            if membersOnly {
                // Navy primary is unreadable on frosted dark chips.
                BadgeLabel(
                    text: "Members Only",
                    color: surface == .dark ? .white : WKCCColors.primary,
                    surface: surface
                )
            }
        }
    }
}

struct DealCategoryMetadataChip: View {
    let category: DealCategory

    var body: some View {
        HStack(spacing: WKCCSpacing.xxs) {
            Image(systemName: category.iconName)
            Text(category.rawValue)
                .lineLimit(1)
        }
        .font(WKCCTypography.captionBold)
        .padding(.horizontal, WKCCSpacing.sm)
        .padding(.vertical, WKCCSpacing.xs)
        .background(WKCCColors.primary.opacity(0.12))
        .foregroundStyle(WKCCColors.primary)
        .clipShape(Capsule())
    }
}

struct DealDetailSectionCard<Content: View>: View {
    let title: String?
    let icon: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        icon: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            if let title {
                if let icon {
                    Label(title, systemImage: icon)
                        .font(WKCCTypography.headline)
                        .foregroundStyle(WKCCColors.textPrimary)
                } else {
                    Text(title)
                        .font(WKCCTypography.headline)
                        .foregroundStyle(WKCCColors.textPrimary)
                }
            }

            content()
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wkccCardStyle()
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

struct ListFilterSheet: View {
    @Binding var selectedCategory: DealCategory?
    var selectedFilter: Binding<DealFilter>? = nil

    @Environment(\.dismiss) private var dismiss

    private var hasActiveFilters: Bool {
        selectedCategory != nil || (selectedFilter?.wrappedValue ?? .all) != .all
    }

    var body: some View {
        NavigationStack {
            List {
                if let selectedFilter {
                    Section("Status") {
                        ForEach(DealFilter.allCases) { filter in
                            filterRow(
                                title: filter.rawValue,
                                iconName: nil,
                                isSelected: selectedFilter.wrappedValue == filter
                            ) {
                                selectedFilter.wrappedValue = filter
                            }
                        }
                    }
                }

                Section("Category") {
                    filterRow(
                        title: "All Categories",
                        iconName: "square.grid.2x2",
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(DealCategory.allCases) { category in
                        filterRow(
                            title: category.rawValue,
                            iconName: category.iconName,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        selectedCategory = nil
                        selectedFilter?.wrappedValue = .all
                    }
                    .disabled(!hasActiveFilters)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func filterRow(
        title: String,
        iconName: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: WKCCSpacing.sm) {
                if let iconName {
                    Image(systemName: iconName)
                        .foregroundStyle(WKCCColors.primary)
                        .frame(width: 22)
                }

                Text(title)
                    .foregroundStyle(WKCCColors.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: WKCCSpacing.xs)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(WKCCColors.accent)
                }
            }
        }
    }
}

struct CategoryChip: View {
    let category: DealCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WKCCSpacing.xxs) {
                Image(systemName: category.iconName)
                Text(category.rawValue)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(WKCCTypography.captionBold)
            .padding(.horizontal, WKCCSpacing.sm)
            .padding(.vertical, WKCCSpacing.xs)
            .background(isSelected ? WKCCColors.primary : WKCCColors.cardBackground)
            .foregroundStyle(isSelected ? WKCCColors.textOnPrimary : WKCCColors.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(WKCCColors.primary.opacity(isSelected ? 0 : 0.15), lineWidth: 1)
            )
        }
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(WKCCTypography.brandCaps)
                .foregroundStyle(WKCCColors.primary)
                .tracking(0.5)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(WKCCTypography.callout)
                    .foregroundStyle(WKCCColors.accent)
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: WKCCSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(WKCCColors.accent)

            Text(title)
                .font(WKCCTypography.headline)
                .foregroundStyle(WKCCColors.textPrimary)

            Text(message)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(WKCCSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: WKCCSpacing.md) {
            ProgressView()
                .tint(WKCCColors.primary)
            Text(message)
                .font(WKCCTypography.callout)
                .foregroundStyle(WKCCColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .wkccPageBackground()
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(WKCCTypography.callout)
            Spacer()
            Button("Dismiss", action: onDismiss)
                .font(WKCCTypography.captionBold)
        }
        .padding(WKCCSpacing.md)
        .background(WKCCColors.error.opacity(0.1))
        .foregroundStyle(WKCCColors.error)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
    }
}

struct WKCCBrandedPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(WKCCSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .wkccCardStyle()
    }
}
