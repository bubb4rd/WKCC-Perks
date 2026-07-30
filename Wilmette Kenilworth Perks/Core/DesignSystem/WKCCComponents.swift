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
                case .failure, .empty:
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

    private let logoSize: CGFloat = 48

    @State private var redemptionDeal: DealDetail?
    @State private var didCopyCode = false
    @State private var isLoadingRedeem = false

    var body: some View {
        VStack(alignment: .leading, spacing: WKCCSpacing.sm) {
            HStack(alignment: .center, spacing: WKCCSpacing.sm) {
                companyLogo

                VStack(alignment: .leading, spacing: 2) {
                    Text(deal.businessName)
                        .font(WKCCTypography.title)
                        .foregroundStyle(WKCCColors.textPrimary)

                    
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            
            Text(deal.title)
                .font(.system(.title3, design: .default).weight(.bold))
                .foregroundStyle(Color.black)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: WKCCSpacing.md) {
                Label(deal.category.rawValue, systemImage: deal.category.iconName)
                    .font(WKCCTypography.body.weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.65))
                    .labelStyle(.titleAndIcon)
                metaRow
                    .frame(alignment: .leading)
                ctaRow
            }
        }
        .padding(WKCCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wkccCardStyle()
        .sheet(item: $redemptionDeal) { detail in
            DealRedemptionSheet(deal: detail, didCopyCode: $didCopyCode)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var ctaRow: some View {
        DealCTARatioSplit(spacing: WKCCSpacing.xs, leadingRatio: 0.4) {
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
                    style: .accent
                )
            }
            .buttonStyle(.plain)
            .disabled(deal.isExpired || isLoadingRedeem)
            .opacity(deal.isExpired ? 0.45 : 1)
        }
        .frame(maxWidth: .infinity)
    }

    private enum DealCTASStyle {
        case secondary
        case accent
    }

    private func dealCTALabel(title: String, systemImage: String, style: DealCTASStyle) -> some View {
        HStack(spacing: WKCCSpacing.xxs) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(WKCCTypography.callout.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(style == .secondary ? Color.black : WKCCColors.textOnPrimary)
        .padding(.horizontal, WKCCSpacing.sm)
        .padding(.vertical, WKCCSpacing.xs)
        .background(style == .secondary ? WKCCColors.cardBackground : WKCCColors.accent)
        .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: WKCCRadius.md)
                .stroke(
                    style == .secondary ? Color.black.opacity(0.35) : Color.clear,
                    lineWidth: 1.5
                )
        )
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
        Image("PerkPlaceholder")
            .resizable()
            .scaledToFill()
            .frame(width: logoSize, height: logoSize)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: WKCCRadius.md))
    }

    private var metaRow: some View {
        HStack(spacing: WKCCSpacing.xs) {
            if let expiration = deal.expirationDate {
                Label {
                    Text(expiration, format: .dateTime.month(.abbreviated).day())
                } icon: {
                    Image(systemName: "clock")
                }
                .font(WKCCTypography.body.weight(.medium))
                .foregroundStyle(deal.isExpiringSoon ? WKCCColors.warning : Color.black.opacity(0.65))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
        }
        .frame(minWidth: 0, alignment: .leading)
    }
}


/// Full-width 2-child split (e.g. 0.4 / 0.6) that stretches to the proposed width.
private struct DealCTARatioSplit: Layout {
    var spacing: CGFloat
    var leadingRatio: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        let width = proposal.width ?? subviews.reduce(CGFloat(0)) { partial, subview in
            partial + subview.sizeThatFits(.unspecified).width
        } + spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }

        let available = max(0, bounds.width - spacing)
        let leadingWidth = available * leadingRatio
        let trailingWidth = available - leadingWidth
        let height = bounds.height

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            proposal: ProposedViewSize(width: leadingWidth, height: height)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + leadingWidth + spacing, y: bounds.minY),
            proposal: ProposedViewSize(width: trailingWidth, height: height)
        )
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
